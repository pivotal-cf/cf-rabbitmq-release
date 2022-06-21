require 'spec_helper'

require 'json'
require 'ostruct'
require 'tempfile'

require 'httparty'

RMQ_VERSION = '3.10'

MQTT_TCP_PORT = "1883"
STOMP_TCP_PORT = "61613"

MQTT_SSL_PORT = "8883"
STOMP_SSL_PORT = "61614"
AMQP_SSL_PORT = "5671"

RSpec.describe 'RabbitMQ server configuration' do
  let(:rmq_host) do
    bosh.indexed_instance('rmq', 0)
  end

  def rabbitmqctl
    'sudo PATH=$PATH:/var/vcap/packages/erlang/bin/ /var/vcap/packages/rabbitmq-server/bin/rabbitmqctl'
  end

  def rabbitmq_diagnostics
    'sudo PATH=$PATH:/var/vcap/packages/erlang/bin/ /var/vcap/packages/rabbitmq-server/privbin/rabbitmq-diagnostics'
  end

  def openssl
    '/var/vcap/packages/openssl/external/openssl/bin/openssl'
  end

  let(:environment_settings) do
    stdout(bosh.ssh(rmq_host, "#{rabbitmqctl} environment"))
  end

  let(:ssl_options) do
    stdout(bosh.ssh(rmq_host, "#{rabbitmqctl} eval 'application:get_env(rabbit, ssl_options).'"))
  end

  def vhost
    'foobar'
  end

  context 'when properties are set' do
    before(:all) do
      manifest = bosh.manifest
      @old_username = get_properties(manifest, 'rmq', 'rabbitmq-server')['rabbitmq-server']['administrators']['management']['username']
      @old_password = get_properties(manifest, 'rmq', 'rabbitmq-server')['rabbitmq-server']['administrators']['management']['password']

      @new_username = 'newusername'
      @new_password = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_abcdefghijklmnopqrstuvwxyz!"#$%&()*+,-./0123456789:;<=>?' # no backtick or single quote supported

      bosh.redeploy do |manifest|
        # Change management creds
        rmq_properties = get_properties(manifest, 'rmq', 'rabbitmq-server')['rabbitmq-server']
        rmq_properties['fd_limit'] = 350_000
        rmq_properties['version'] = RMQ_VERSION

        management_credentials = rmq_properties['administrators']['management']
        management_credentials['username'] = @new_username
        management_credentials['password'] = @new_password

        # SSL
        server_key = File.read(File.join(__dir__, '../..', '/spec/assets/server_key.pem'))
        server_cert = File.read(File.join(__dir__, '../..', '/spec/assets/server_certificate.pem'))
        ca_cert = File.read(File.join(__dir__, '../..', '/spec/assets/ca_certificate.pem'))

        rmq_properties = get_properties(manifest, 'rmq', 'rabbitmq-server')['rabbitmq-server']
        rmq_properties['ssl'] = {}
        rmq_properties['ssl']['enabled'] = true
        rmq_properties['ssl']['key'] = server_key
        rmq_properties['ssl']['cert'] = server_cert
        rmq_properties['ssl']['cacert'] = ca_cert
        rmq_properties['ssl']['versions'] = ['tlsv1.2', 'tlsv1.1', 'tlsv1']
        rmq_properties['ssl']['disable_non_ssl_listeners'] = true

        tlsv1_compatible_cipher = 'ECDHE-RSA-AES256-SHA'
        tlsv1_2_compatible_cipher = 'ECDHE-RSA-AES256-GCM-SHA384'
        rmq_properties['ssl']['ciphers'] = [tlsv1_compatible_cipher, tlsv1_2_compatible_cipher]

        rmq_ssl_properties = get_properties(manifest, 'rmq', 'rabbitmq-server')['rabbitmq-server']['ssl']
        rmq_ssl_properties['verify'] = true
        rmq_ssl_properties['verification_depth'] = 10
        rmq_ssl_properties['fail_if_no_peer_cert'] = true

        # Load Definitions
        rmq_properties = get_properties(manifest, 'rmq', 'rabbitmq-server')['rabbitmq-server']
        rmq_properties['load_definitions'] = {}
        rmq_properties['load_definitions']['vhosts'] = [{ 'name' => vhost }]
      end
    end

    after(:all) do
      bosh.deploy(test_manifest)
    end

    it "should deploy RabbitMQ #{RMQ_VERSION}" do
        creds = admin_creds
        response = get("#{rabbitmq_api_url}/overview", creds['username'], creds['password'])

        expect(response['rabbitmq_version']).to start_with(RMQ_VERSION)
    end

    context 'when management credentials are rolled' do
      it 'it can only access the management HTTP API with the new credentials' do
        manifest = bosh.manifest
        rabbitmq_api = get_properties(manifest, 'haproxy', 'route_registrar')['route_registrar']['routes'].first['uris'].first

        response = HTTParty.get("http://#{rabbitmq_api}/api/whoami", basic_auth: { username: @new_username, password: @new_password })
        expect(response.code).to eq 200

        response = HTTParty.get("http://#{rabbitmq_api}/api/whoami", basic_auth: { username: @old_username, password: @old_password })
        expect(response.code).to eq 401
      end
    end

    describe 'SSL' do
      def connect_using(tls_version)
        "#{openssl} s_client -#{tls_version} -connect 127.0.0.1:5671"
      end

      it 'enables SSL listeners' do
          output = bosh.ssh(rmq_host, "#{rabbitmq_diagnostics} listeners")
          # regex in order not to match the management api ssl port 15671
          amqp_ssl_port_regex = AMQPPortRegex.ssl_regex

          expect(stdout(output)).to include(MQTT_SSL_PORT)
          expect(stdout(output)).to include(STOMP_SSL_PORT)
          expect(stdout(output)).to match(amqp_ssl_port_regex)
      end

      context 'when tlsv1, tlsv1.1 and tlsv1.2 are enabled' do
        before(:all) do
          manifest = bosh.manifest

          bosh.redeploy do |manifest|
            rmq_properties = get_properties(manifest, 'rmq', 'rabbitmq-server')['rabbitmq-server']
            rmq_properties['ssl']['versions'] = ['tlsv1.2', 'tlsv1.1', 'tlsv1']

            tlsv1_compatible_cipher = 'ECDHE-RSA-AES256-SHA'
            tlsv1_2_compatible_cipher = 'ECDHE-RSA-AES256-GCM-SHA384'
            rmq_properties['ssl']['ciphers'] = [tlsv1_compatible_cipher, tlsv1_2_compatible_cipher]
          end
        end

        it 'should have TLS 1.0 enabled' do
          output = bosh.ssh(rmq_host, connect_using('tls1'))

          expect(stdout(output)).to include('BEGIN CERTIFICATE')
          expect(stdout(output)).to include('END CERTIFICATE')
        end

        it 'should have TLS 1.1 enabled' do
          output = bosh.ssh(rmq_host, connect_using('tls1_1'))

          expect(stdout(output)).to include('BEGIN CERTIFICATE')
          expect(stdout(output)).to include('END CERTIFICATE')
        end

        it 'should have TLS 1.2 enabled' do
          output = bosh.ssh(rmq_host, connect_using('tls1_2'))

          expect(stdout(output)).to include('BEGIN CERTIFICATE')
          expect(stdout(output)).to include('END CERTIFICATE')
        end

        context 'when client connects with a cipher not configured on the server' do
          it 'should not be able to connect' do
            output = bosh.ssh(rmq_host, 'openssl s_client -cipher AES256-SHA256 -connect 127.0.0.1:5671')
            expect(stdout(output)).to include('insufficient security')
          end
        end
      end

      context 'when tlsv1.2 and tlsv1.3 are enabled' do
        before(:all) do
          manifest = bosh.manifest

          bosh.redeploy do |manifest|
            rmq_properties = get_properties(manifest, 'rmq', 'rabbitmq-server')['rabbitmq-server']
            rmq_properties['ssl']['versions'] = ['tlsv1.3', 'tlsv1.2']

            tlsv1_2_compatible_cipher = 'ECDHE-RSA-AES256-GCM-SHA384'
            tlsv1_3_compatible_cipher = 'TLS_AES_256_GCM_SHA384'
            rmq_properties['ssl']['ciphers'] = [tlsv1_2_compatible_cipher, tlsv1_3_compatible_cipher]
          end
        end
        it 'should have TLS 1.2 enabled' do
          output = bosh.ssh(rmq_host, connect_using('tls1_2'))

          expect(stdout(output)).to include('BEGIN CERTIFICATE')
          expect(stdout(output)).to include('END CERTIFICATE')
        end

        it 'should have TLS 1.3 enabled' do
          output = bosh.ssh(rmq_host, connect_using('tls1_3'))

          expect(stdout(output)).to include('BEGIN CERTIFICATE')
          expect(stdout(output)).to include('END CERTIFICATE')
        end
      end

      context 'when verification and validation is enabled' do
        it 'has the right SSL verification options' do
          expect(ssl_options).to include('{verify,verify_peer}')
        end

        it 'has the right SSL verification depth option' do
          expect(ssl_options).to include('{depth,10}')
        end

        it 'has the right SSL peer options' do
          expect(ssl_options).to include('{fail_if_no_peer_cert,true}')
        end
      end

      context 'when disable non SSL listeners is set' do
        it 'disables the non SSL listeners' do
          output = bosh.ssh(rmq_host, "#{rabbitmq_diagnostics} listeners")
          # regex in order not to match the management api port 15672
          amqp_tcp_regex = AMQPPortRegex.regex

          expect(stdout(output)).not_to include(MQTT_TCP_PORT)
          expect(stdout(output)).not_to include(STOMP_TCP_PORT)
          expect(stdout(output)).not_to match(amqp_tcp_regex)
        end
      end
    end

    describe 'load definitions' do
      it 'creates a vhost when vhost definition is provided' do
        creds = admin_creds
        response = get("#{rabbitmq_api_url}/vhosts/#{vhost}", creds['username'], creds['password'])

        expect(response['name']).to eq(vhost)
      end
    end
  end
end

def admin_creds
  get_properties(bosh.manifest, 'rmq', 'rabbitmq-server')['rabbitmq-server']['administrators']['management']
end

def stdout(output)
  output['Tables'].first['Rows'].first['stdout']
end

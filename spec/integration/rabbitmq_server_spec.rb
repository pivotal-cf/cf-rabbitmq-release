require 'spec_helper'

require 'json'
require 'ostruct'
require 'tempfile'

require 'httparty'

RSpec.describe 'RabbitMQ server configuration' do
  let(:rmq_host) do
    bosh.indexed_instance('rmq', 0)
  end

  let(:environment_settings) do
    stdout(bosh.ssh(rmq_host, 'sudo ERL_DIR=/var/vcap/packages/erlang/bin/ /var/vcap/packages/rabbitmq-server/bin/rabbitmqctl environment'))
  end

  let(:ssl_options) do
    stdout(bosh.ssh(rmq_host, "sudo ERL_DIR=/var/vcap/packages/erlang/bin/ /var/vcap/packages/rabbitmq-server/bin/rabbitmqctl eval 'application:get_env(rabbit, ssl_options).'"))
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
      @new_password = 'newpassword'

      bosh.redeploy do |manifest|
        # Change management creds
        rmq_properties = get_properties(manifest, 'rmq', 'rabbitmq-server')['rabbitmq-server']
        rmq_properties['fd_limit'] = 350_000

        management_credentials = rmq_properties['administrators']['management']
        management_credentials['username'] = @new_username
        management_credentials['password'] = @new_password

        # SSL
        server_key = File.read(File.join(__dir__, '../..', '/spec/assets/server_key.pem'))
        server_cert = File.read(File.join(__dir__, '../..', '/spec/assets/server_certificate.pem'))
        ca_cert = File.read(File.join(__dir__, '../..', '/spec/assets/ca_certificate.pem'))

        rmq_properties = get_properties(manifest, 'rmq', 'rabbitmq-server')['rabbitmq-server']
        rmq_properties['ssl'] = Hash.new
        rmq_properties['ssl']['key'] = server_key
        rmq_properties['ssl']['cert'] = server_cert
        rmq_properties['ssl']['cacert'] = ca_cert
        rmq_properties['ssl']['versions'] = ['tlsv1.2','tlsv1.1', 'tlsv1']

        tlsv1_compatible_cipher = 'ECDHE-RSA-AES256-SHA'
        tlsv1_2_compatible_cipher = 'ECDHE-RSA-AES256-GCM-SHA384'
        rmq_properties['ssl']['ciphers'] = [tlsv1_compatible_cipher, tlsv1_2_compatible_cipher]

        rmq_ssl_properties = get_properties(manifest, 'rmq', 'rabbitmq-server')['rabbitmq-server']['ssl']
        rmq_ssl_properties['verify'] = true
        rmq_ssl_properties['verification_depth'] = 10
        rmq_ssl_properties['fail_if_no_peer_cert'] = true

        # Load Definitions
        rmq_properties = get_properties(manifest, 'rmq', 'rabbitmq-server')['rabbitmq-server']
        rmq_properties['load_definitions'] = Hash.new
        rmq_properties['load_definitions']['vhosts'] = [{'name'=> vhost}]
      end
    end

    after(:all) do
      bosh.deploy(test_manifest)
    end

    context 'when management credentials are rolled' do
      it 'it can only access the management HTTP API with the new credentials' do
        manifest = bosh.manifest
        rabbitmq_api = get_properties(manifest, 'haproxy', 'route_registrar')['route_registrar']['routes'].first['uris'].first

        response = HTTParty.get("http://#{rabbitmq_api}/api/whoami", {:basic_auth => {:username => @new_username, :password => @new_password}})
        expect(response.code).to eq 200

        response = HTTParty.get("http://#{rabbitmq_api}/api/whoami", {:basic_auth => {:username => @old_username, :password => @old_password}})
        expect(response.code).to eq 401
      end
    end

    describe 'SSL' do
      context "when tlsv1, tlsv1.1, and tlsv1.2 are enabled" do
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

        def connect_using(tls_version)
          "openssl s_client -#{tls_version} -connect 127.0.0.1:5671"
        end

        context 'when client connects with a cipher not configured on the server' do
          it 'should not be able to connect' do
            output = bosh.ssh(rmq_host, "openssl s_client -cipher AES256-SHA256 -connect 127.0.0.1:5671")
            expect(stdout(output)).to include('insufficient security')
          end
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

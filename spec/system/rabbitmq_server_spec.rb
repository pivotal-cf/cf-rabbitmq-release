require 'spec_helper'

require 'json'
require 'ostruct'
require 'tempfile'

require 'hula'
require 'hula/bosh_manifest'

RSpec.describe "RabbitMQ server configuration" do
  let(:rmq_host) { bosh_director.ips_for_job("rmq", environment.bosh_manifest.deployment_name)[0] }
  let(:rmq_admin_broker_username) { environment.bosh_manifest.property('rabbitmq-server.administrators.broker.username') }
  let(:rmq_admin_broker_password) { environment.bosh_manifest.property('rabbitmq-server.administrators.broker.password') }
  let(:environment_settings) {  ssh_gateway.execute_on(rmq_host, "ERL_DIR=/var/vcap/packages/erlang/bin/ /var/vcap/packages/rabbitmq-server/bin/rabbitmqctl environment", :root => true) }
  let(:ssl_options) {  ssh_gateway.execute_on(rmq_host, "ERL_DIR=/var/vcap/packages/erlang/bin/ /var/vcap/packages/rabbitmq-server/bin/rabbitmqctl eval 'application:get_env(rabbit, ssl_options).'", :root => true) }

  describe "Defaults" do
    it "should have a file descriptor limit set by default in BOSH spec" do
      output = ssh_gateway.execute_on(rmq_host, "curl -u #{rmq_admin_broker_username}:#{rmq_admin_broker_password} http://#{rmq_host}:15672/api/nodes -s")
      nodes = JSON.parse(output)
      nodes.each do |node|
        expect(node["fd_total"]).to eq 300000
      end
    end

    it "should be use autoheal partition handling policy" do
      expect(environment_settings).to include('{cluster_partition_handling,autoheal}')
    end

    it "should have disk free limit set to '{mem_relative,0.4}' as default" do
      expect(environment_settings).to include('{disk_free_limit,{mem_relative,0.4}}')
    end

    it 'does not have SSL verification enabled and peer validation enabled' do
      expect(ssl_options).to include('{ok,[]}')
    end
  end

  context 'when properties are set' do
    before(:all) do
      @ha_host = bosh_director.ips_for_job('haproxy', environment.bosh_manifest.deployment_name)[0]
      @old_username = environment.bosh_manifest.property("rabbitmq-server.administrators.management.username")
      @old_password = environment.bosh_manifest.property("rabbitmq-server.administrators.management.password")

      @new_username = 'newusername'
      @new_password = 'newpassword'

      modify_and_deploy_manifest do |manifest|
        manifest['properties']['rabbitmq-server']['disk_alarm_threshold'] = '20000000'
        manifest['properties']['rabbitmq-server']['cluster_partition_handling'] = 'pause_minority'
        manifest["properties"]["rabbitmq-server"]["fd_limit"] = 350000

        management_credentials = manifest['properties']['rabbitmq-server']['administrators']['management']
        management_credentials['username'] = @new_username
        management_credentials['password'] = @new_password
      end
    end

    after(:all) do
      bosh_director.deploy(environment.bosh_manifest.path)
    end

    it "should have hard disk alarm threshold of 20 MB" do
      expect(environment_settings).to include('{disk_free_limit,20000000}')
    end

    it "should be use pause_minority" do
      expect(environment_settings).to include('{cluster_partition_handling,pause_minority}')
    end

    it "should have a file descriptor limit reflecting that" do
      output = ssh_gateway.execute_on(rmq_host, "curl -u #{@new_username}:#{@new_password} http://#{rmq_host}:15672/api/nodes -s")
      nodes = JSON.parse(output)

      nodes.each do |node|
        # pause_minority causes one of the nodes to be down
        if node["running"]
          expect(node["fd_total"]).to eq 350000
        end
      end
    end

    it 'it can only access the management HTTP API with the new credentials' do
      ssh_gateway.with_port_forwarded_to(@ha_host, 15_672) do |port|

        uri = URI("http://localhost:#{port}/api/whoami")
        code = response_code(uri, {
          :username => @new_username,
          :password => @new_password
        })
        expect(code).to eq "200"

        code = response_code(uri, {
          :username => @old_username,
          :password => @old_password
        })
        expect(code).to eq "401"
      end
    end
  end

  describe 'SSL' do
    context 'when is configured' do
      before(:all) do
        server_key = File.read(File.join(__dir__, '../..', '/spec/assets/server_key.pem'))
        server_cert = File.read(File.join(__dir__, '../..', '/spec/assets/server_certificate.pem'))
        ca_cert = File.read(File.join(__dir__, '../..', '/spec/assets/ca_certificate.pem'))

        modify_and_deploy_manifest do |manifest|
          @current_manifest = manifest

          manifest['properties']['rabbitmq-server']['ssl'] = Hash.new
          manifest['properties']['rabbitmq-server']['ssl']['key'] = server_key
          manifest['properties']['rabbitmq-server']['ssl']['cert'] = server_cert
          manifest['properties']['rabbitmq-server']['ssl']['cacert'] = ca_cert
          manifest['properties']['rabbitmq-server']['ssl']['security_options'] = ['enable_tls1_0']
        end
      end

      after(:all) do
        bosh_director.deploy(environment.bosh_manifest.path)
      end

      context 'when verification and validation is enabled' do
        before(:all) do
          @current_manifest['properties']['rabbitmq-server']['ssl']['verify'] = true
          @current_manifest['properties']['rabbitmq-server']['ssl']['verification_depth'] = 10
          @current_manifest['properties']['rabbitmq-server']['ssl']['fail_if_no_peer_cert'] = true
          deploy_manifest(@current_manifest)
        end

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

      it 'does not have SSL verification enabled' do
        expect(ssl_options).to include('{verify,verify_none}')
      end

      it 'does not have SSL peer validation enabled' do
        expect(ssl_options).to include('{fail_if_no_peer_cert,false}')
      end

      it 'has the right SSL verification depth option' do
        expect(ssl_options).to include('{depth,5}')
      end

      describe "TLS" do
        it 'should have TLS 1.0 enabled' do
          expect(tls_version_enabled?(rmq_host, 'tls1')).to be_truthy
        end

        it 'should have TLS 1.1 enabled' do
          expect(tls_version_enabled?(rmq_host, 'tls1_1')).to be_truthy
        end

        it 'should have TLS 1.2 enabled' do
          expect(tls_version_enabled?(rmq_host, 'tls1_2')).to be_truthy
        end
      end
    end
  end
end

def response_code(uri, credentials)
  req = Net::HTTP::Get.new(uri)
  req.basic_auth credentials[:username], credentials[:password]

  res = Net::HTTP.start(uri.hostname, uri.port) do |http|
    http.request(req)
  end

  return res.code
end

def tls_version_enabled?(host, version)
  cmd = "openssl s_client -#{version} -connect 127.0.0.1:5671"

  output = ssh_gateway.execute_on(host, cmd)
  (output =~ /BEGIN CERTIFICATE/ && output =~ /END CERTIFICATE/) != nil
end

require 'spec_helper'

require 'json'
require 'ostruct'
require 'tempfile'

require 'hula'
require 'hula/bosh_manifest'

describe "RabbitMQ server configuration" do

  let(:rmq_host) { bosh_director.ips_for_job("rmq_z1", environment.bosh_manifest.deployment_name)[0] }
  let(:rmq_admin_broker_username) { environment.bosh_manifest.property('rabbitmq-server.administrators.broker.username') }
  let(:rmq_admin_broker_password) { environment.bosh_manifest.property('rabbitmq-server.administrators.broker.password') }

  it "should have a file descriptor limit set by default in BOSH spec" do
    output = ssh_gateway.execute_on(rmq_host, "curl -u #{rmq_admin_broker_username}:#{rmq_admin_broker_password} http://#{rmq_host}:15672/api/nodes -s")
    nodes = JSON.parse(output)
    nodes.each do |node|
      expect(node["fd_total"]).to eq 300000
    end
  end

  it 'should have TLS enabled' do
    expect(tls_version_enabled?(rmq_host, 'tls1')).to be_truthy
    expect(tls_version_enabled?(rmq_host, 'tls1_1')).to be_truthy
    expect(tls_version_enabled?(rmq_host, 'tls1_2')).to be_truthy
  end

  describe 'SSL' do
    let(:ssl_options) {  ssh_gateway.execute_on(rmq_host, "ERL_DIR=/var/vcap/packages/erlang/bin/ /var/vcap/packages/rabbitmq-server/bin/rabbitmqctl eval 'application:get_env(rabbit, ssl_options).'", :root => true) }

    it 'does not have SSL verification enabled' do
      expect(ssl_options).to include('{verify,verify_none}')
    end

    it 'does not have SSL peer validation enabled' do
      expect(ssl_options).to include('{fail_if_no_peer_cert,false}')
    end

    context 'when SSL verification and peer validation is enabled' do
      before(:each) do
        modify_and_deploy_manifest do |manifest|
          manifest['properties']['rabbitmq-server']['ssl']['verify'] = true
          manifest['properties']['rabbitmq-server']['ssl']['fail_if_no_peer_cert'] = true
        end
      end

      after(:each) do
        bosh_director.deploy(environment.bosh_manifest.path)
      end

      it 'has the right SSL verification options' do
        expect(ssl_options).to include('{verify,verify_peer}')
      end

      it 'has the right SSL peer options' do
        expect(ssl_options).to include('{fail_if_no_peer_cert,true}')
      end
    end
  end


  context "when the manifest specifies a different file descriptor limit" do
    before :context do
      modify_and_deploy_manifest do |manifest|
        manifest["properties"]["rabbitmq-server"]["fd_limit"] = 350000
      end
    end

    after :context do
      modify_and_deploy_manifest do |manifest|
        bosh_director.deploy(environment.bosh_manifest.path)
      end
    end

    it "should have a file descriptor limit reflecting that" do
      output = ssh_gateway.execute_on(rmq_host, "curl -u #{rmq_admin_broker_username}:#{rmq_admin_broker_password} http://#{rmq_host}:15672/api/nodes -s")
      nodes = JSON.parse(output)
      nodes.each do |node|
        expect(node["fd_total"]).to eq 350000
      end
    end
  end

  context 'when the RabbitMQ management credentials are changed' do
    before :context do
      @ha_host = bosh_director.ips_for_job('haproxy_z1', environment.bosh_manifest.deployment_name)[0]
      @old_username = environment.bosh_manifest.property("rabbitmq-server.administrators.management.username")
      @old_password = environment.bosh_manifest.property("rabbitmq-server.administrators.management.password")

      @new_username = 'newusername'
      @new_password = 'newpassword'

      modify_and_deploy_manifest do |manifest|
        management_credentials = manifest['properties']['rabbitmq-server']['administrators']['management']
        management_credentials['username'] = @new_username
        management_credentials['password'] = @new_password
      end
    end

    after :context do
      bosh_director.deploy(environment.bosh_manifest.path)
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

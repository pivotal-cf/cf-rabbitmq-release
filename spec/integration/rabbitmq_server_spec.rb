require 'spec_helper'

require 'json'
require 'ostruct'
require 'tempfile'

require 'hula'
require 'hula/bosh_manifest'

RSpec.describe 'RabbitMQ server configuration' do
  let(:rmq_host) { bosh_director.ips_for_job('rmq', environment.bosh_manifest.deployment_name)[0] }
  let(:rmq_admin_broker_username) { get_properties(manifest(), 'rmq', 'rabbitmq-server')['rabbitmq-server']['administrators']['broker']['username'] }
  let(:rmq_admin_broker_password) { get_properties(manifest(), 'rmq', 'rabbitmq-server')['rabbitmq-server']['administrators']['broker']['password'] }

  let(:environment_settings) {  ssh_gateway.execute_on(rmq_host, 'ERL_DIR=/var/vcap/packages/erlang/bin/ /var/vcap/packages/rabbitmq-server/bin/rabbitmqctl environment', :root => true) }
  let(:ssl_options) {  ssh_gateway.execute_on(rmq_host, "ERL_DIR=/var/vcap/packages/erlang/bin/ /var/vcap/packages/rabbitmq-server/bin/rabbitmqctl eval 'application:get_env(rabbit, ssl_options).'", :root => true) }

  describe 'Defaults' do
    it 'should be use pause_minority partition handling policy' do
      expect(environment_settings).to include('{cluster_partition_handling,pause_minority}')
    end

    it 'should have disk free limit set to "{mem_relative,0.4}" as default' do
      expect(environment_settings).to include('{disk_free_limit,{mem_relative,0.4}}')
    end

    it 'does not have SSL verification enabled and peer validation enabled' do
      expect(ssl_options).to include('{ok,[]}')
    end
  end

  context 'when properties are set' do
    before(:all) do
      @ha_host = bosh_director.ips_for_job('haproxy', environment.bosh_manifest.deployment_name)[0]
      @old_username = get_properties(manifest(), 'rmq', 'rabbitmq-server')['rabbitmq-server']['administrators']['management']['username']
      @old_password = get_properties(manifest(), 'rmq', 'rabbitmq-server')['rabbitmq-server']['administrators']['management']['password']

      @new_username = 'newusername'
      @new_password = 'newpassword'

      modify_and_deploy_manifest do |manifest|
        rmq_properties = get_properties(manifest, 'rmq', 'rabbitmq-server')['rabbitmq-server']
        rmq_properties['disk_alarm_threshold'] = '20000000'
        rmq_properties['cluster_partition_handling'] = 'pause_minority'
        rmq_properties['fd_limit'] = 350000

        management_credentials = rmq_properties['administrators']['management']
        management_credentials['username'] = @new_username
        management_credentials['password'] = @new_password
      end
    end

    after(:all) do
      bosh_director.deploy(environment.bosh_manifest.path)
    end

    it 'should have hard disk alarm threshold of 20 MB' do
      expect(environment_settings).to include('{disk_free_limit,20000000}')
    end

    it 'should be use pause_minority' do
      expect(environment_settings).to include('{cluster_partition_handling,pause_minority}')
    end

    it 'it can only access the management HTTP API with the new credentials' do
      ssh_gateway.with_port_forwarded_to(@ha_host, 15_672) do |port|

        uri = URI("http://localhost:#{port}/api/whoami")
        code = response_code(uri, {
          :username => @new_username,
          :password => @new_password
        })
        expect(code).to eq '200'

        code = response_code(uri, {
          :username => @old_username,
          :password => @old_password
        })
        expect(code).to eq '401'
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

          rmq_properties = get_properties(manifest, 'rmq', 'rabbitmq-server')['rabbitmq-server']
          rmq_properties['ssl'] = Hash.new
          rmq_properties['ssl']['key'] = server_key
          rmq_properties['ssl']['cert'] = server_cert
          rmq_properties['ssl']['cacert'] = ca_cert
          rmq_properties['ssl']['security_options'] = ['enable_tls1_0']
        end
      end

      after(:all) do
        bosh_director.deploy(environment.bosh_manifest.path)
      end

      context 'when verification and validation is enabled' do
        before(:all) do
          rmq_ssl_properties = get_properties(@current_manifest, 'rmq', 'rabbitmq-server')['rabbitmq-server']['ssl']
          rmq_ssl_properties['verify'] = true
          rmq_ssl_properties['verification_depth'] = 10
          rmq_ssl_properties['fail_if_no_peer_cert'] = true
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

  describe 'load definitions' do
    vhost = 'foobar'

    before(:each) do
      modify_and_deploy_manifest do |manifest|
        rmq_properties = get_properties(manifest, 'rmq', 'rabbitmq-server')['rabbitmq-server']
        rmq_properties['load_definitions'] = Hash.new
        rmq_properties['load_definitions']['vhosts'] = [{'name'=> vhost}]
      end
    end

    it 'creates a vhost when vhost definition is provided' do
      output = ssh_gateway.execute_on(rmq_host, "curl -u #{rmq_admin_broker_username}:#{rmq_admin_broker_password} http://#{rmq_host}:15672/api/vhosts/#{vhost} -s")
      response = JSON.parse(output)
      expect(response['name']).to eq(vhost)
    end
  end

  describe 'when changing the cookie' do
    before(:each) do
      modify_and_deploy_manifest do |manifest|
        rmq_properties = get_properties(manifest, 'rmq', 'rabbitmq-server')['rabbitmq-server']
        rmq_properties['cookie'] = 'change-the-cookie'
      end
    end

    after(:each) do
      bosh_director.deploy(environment.bosh_manifest.path)
    end

    it 'all the nodes come back' do
      output = ssh_gateway.execute_on(rmq_host, "curl -u #{rmq_admin_broker_username}:#{rmq_admin_broker_password} http://#{rmq_host}:15672/api/nodes -s")
      nodes = JSON.parse(output)
      expect(nodes.size).to eq(3)
      nodes.each do |node|
        expect(node['running']).to eq(true)

        applications = (node['applications'] || []).map{|app| app['name']}
        expect(applications).to include('rabbit')
        expect(applications).to include('rabbitmq_management')
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

def get_properties(manifest, instance_group_name, job_name)
  instance_group = manifest['instance_groups'].select{ |instance_group| instance_group['name'] == instance_group_name }.first
  raise "No instance group named #{instance_group_name} found in manifest:\n#{manifest}" if instance_group.nil?

  job = instance_group['jobs'].select{ |job| job['name'] == job_name }.first
  raise "No job named #{job_name} found in instance group named #{instance_group_name} in manifest:\n#{manifest}" if job.nil?

  raise "No properties found for job #{job_name} in instance group #{instance_group_name} in manifest\n#{manifest}" if not job.key?('properties')
  job['properties']
end

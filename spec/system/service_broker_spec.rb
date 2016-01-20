require 'spec_helper'

require 'json'
require 'ostruct'
require 'tempfile'

require 'hula'
require 'hula/bosh_manifest'
require 'prof/marketplace_service'
require 'prof/service_instance'
require 'prof/cloud_foundry'
require 'prof/test_app'
require 'rabbitmq/http/client'

require "mqtt"
require "stomp"

require File.expand_path('../../../system_test/test_app/lib/lab_rat/aggregate_health_checker.rb', __FILE__)

describe 'Using a Cloud Foundry service broker' do
  before(:all) do
    register_broker
  end

  after(:all) do
    deregister_broker
  end

  let(:service_name) { environment.bosh_manifest.property('rabbitmq-broker.service.name') }

  let(:service) do
    Prof::MarketplaceService.new(
      name: service_name,
      plan: 'standard'
    )
  end

  let(:session) { Capybara::Session.new(:poltergeist) }

  context 'default deployment'  do
    before :context do
      @rmq_host = bosh_director.ips_for_job("rmq_z1", environment.bosh_manifest.deployment_name)[0]
      @rmq_admin_broker_username = environment.bosh_manifest.property('rabbitmq-server.administrators.broker.username')
      @rmq_admin_broker_password = environment.bosh_manifest.property('rabbitmq-server.administrators.broker.password')
    end

    it 'provides defaults', :pushes_cf_app do
      cf.push_app_and_bind_with_service(test_app, service) do |app, _|

        provides_amqp_connectivity(session, app)

        provides_mqtt_connectivity(session, app)

        provides_stomp_connectivity(session, app)

        provides_mirrored_queue_policy_as_a_default(app)
      end
    end

    it 'enables TLS 1.0' do
      rabbitmq_host = bosh_director.ips_for_job('rmq_z1', environment.bosh_manifest.deployment_name).first

      expect(tls_version_enabled?(rabbitmq_host, 'tls1')).to be_truthy
      expect(tls_version_enabled?(rabbitmq_host, 'tls1_1')).to be_truthy
      expect(tls_version_enabled?(rabbitmq_host, 'tls1_2')).to be_truthy
    end
  end

  context 'when provisioning a service key' do
    it 'provides defaults', :creates_service_key do
      cf.provision_and_create_service_key(service) do |service_instance, service_key, service_key_data|
        provides_direct_amqp_connectivity(service_key_data)

        provides_direct_stomp_connectivity(service_key_data)
      end
    end
  end

  context 'when deprovisioning a service key' do
    it 'is no longer listed in service-keys', :creates_service_key do
      cf.provision_and_create_service_key(service) do |service_instance, service_key, service_key_data|
        @service_instance = service_instance
        @service_key = service_key
        @service_key_data = service_key_data

        cf.delete_service_key(@service_instance, @service_key)

        expect(cf.list_service_keys(@service_instance)).to_not include(@service_key)
        expect{
          provides_direct_amqp_connectivity(@service_key_data)
        }.to raise_error(/Authentication with RabbitMQ failed./)
      end
    end
  end

  context 'when a dns host is configured' do
    before :context do
      modify_and_deploy_manifest do |manifest|
        rabbit_manifest = manifest['properties']['rabbitmq-broker']['rabbitmq']
        rabbit_manifest['dns_host'] = rabbit_manifest['hosts'].first
        rabbit_manifest['hosts'] = ['Verify that this ip is not used over the dns_host']
      end
    end

    after :context do
      bosh_director.deploy(environment.bosh_manifest.path)
    end

    it 'is still possible to read and write to a queue', :pushes_cf_app do
      cf.push_app_and_bind_with_service(test_app, service) do |app, _|
        session.visit "#{app.url}/services/rabbitmq/protocols/amqp091"
        expect(session.status_code).to eql(200)
        expect(session).to have_content('amq.gen')
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

  describe 'high availability' do
    %w(rmq_z1 rmq_z2).each do |job_name|
      context "when the job #{job_name}/0 is down", :pushes_cf_app do
        before(:all) do
          bosh_director.stop(job_name, 0)
        end

        after(:all) do
          bosh_director.start(job_name, 0)
        end

        it 'is still possible to read and write to a queue' do
          cf.push_app_and_bind_with_service(test_app, service) do |app, _|
            session.visit "#{app.url}/services/rabbitmq/protocols/amqp091"
            expect(session.status_code).to eql(200)
            expect(session).to have_content('amq.gen')
          end
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

def provides_amqp_connectivity(session, app)
  session.visit "#{app.url}/services/rabbitmq/protocols/amqp091"

  expect(session.status_code).to eql(200)
  expect(session).to have_content('amq.gen')
end

def provides_mqtt_connectivity(session, app)
  session.visit "#{app.url}/services/rabbitmq/protocols/mqtt"

  expect(session.status_code).to eql(200)
  expect(session).to have_content('mqtt://')
  expect(session).to have_content('Payload published')

  queues = ssh_gateway.execute_on(@rmq_host, "curl -u #{@rmq_admin_broker_username}:#{@rmq_admin_broker_password} http://#{@rmq_host}:15672/api/queues -s")
  json = JSON.parse(queues)
  json.select!{ |queue| queue["name"] == "mqtt-subscription-mqtt_test_clientqos1" }
  expect(json.length).to eql(1)
  expect(json[0]["arguments"]["x-expires"]).to eql(1800000)
end

def provides_stomp_connectivity(session, app)
  session.visit "#{app.url}/services/rabbitmq/protocols/stomp"

  expect(session.status_code).to eql(200)
  expect(session).to have_content('Payload published')
end

def provides_direct_amqp_connectivity(service_key_data)
  amqp_proto = service_key_data['protocols']['amqp+ssl'].dup

  result = ssh_gateway.with_port_forwarded_to(amqp_proto['host'], amqp_proto['port']) do |port|
    hc = LabRat::AggregateHealthChecker.new
    amqp_gateway_proto = ssh_gateway_proto(amqp_proto, port)
    hc.check_amqp(amqp_gateway_proto)
  end

  expect(result).to_not be_empty
  expect(result[:exception]).to be_nil
  expect(result[:queue].name).to match('amq.gen')
end

def provides_direct_stomp_connectivity(service_key_data)
  stomp_proto = service_key_data['protocols']['stomp'].dup

  result = ssh_gateway.with_port_forwarded_to(stomp_proto['host'], stomp_proto['port']) do |port|
    hc = LabRat::AggregateHealthChecker.new
    stomp_gateway_proto = ssh_gateway_proto(stomp_proto, port)
    hc.check_stomp(stomp_gateway_proto)
  end

  expect(result).to_not be_empty
  expect(result[:exception]).to be_nil
  expect(result[:payload]).to match('stomp')
end

def ssh_gateway_proto(proto, port)
  gw_proto = proto.dup
  gw_proto['uri'].gsub! proto['host'], 'localhost'
  gw_proto['uri'].gsub! proto['port'].to_s, port.to_s
  gw_proto['uris'] = [gw_proto['uri']]
  gw_proto['host'] = 'localhost'
  gw_proto['hosts'] = [gw_proto['host']]
  gw_proto['port'] = port
  gw_proto
end

def provides_mirrored_queue_policy_as_a_default(app)
  credentials = cf.app_vcap_services(app.name)
  management_credentials = credentials[service_name].first['credentials']['protocols']['management+ssl']

  ssh_gateway.with_port_forwarded_to(management_credentials['host'], management_credentials['port']) do |port|
    endpoint = "http://localhost:#{port}"

    client = RabbitMQ::HTTP::Client.new(endpoint,
                                        username: management_credentials['username'],
                                        password: management_credentials['password'],
                                        ssl: {
                                          verify: false
                                        })

    vhost = credentials[service_name].first['credentials']['protocols']['amqp+ssl']['vhost']
    policy = client.list_policies(vhost).find do |policy|
      policy['name'] == 'operator_set_policy'
    end

    expect(policy).to_not be_nil
    expect(policy['pattern']).to eq('.*')
    expect(policy['apply-to']).to eq('all')
    expect(policy['definition']).to eq('ha-mode' => 'exactly', 'ha-params' => 2, 'ha-sync-mode' => 'automatic')
    expect(policy['priority']).to eq(50)
  end
end

def tls_version_enabled?(host, version)
  cmd = "openssl s_client -#{version} -connect 127.0.0.1:5671"

  output = ssh_gateway.execute_on(host, cmd)
  (output =~ /BEGIN CERTIFICATE/ && output =~ /END CERTIFICATE/) != nil
end

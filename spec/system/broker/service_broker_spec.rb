require 'spec_helper'

require 'json'
require 'ostruct'
require 'tempfile'
require 'net/https'
require 'uri'

require 'hula'
require 'hula/bosh_manifest'
require 'prof/marketplace_service'
require 'prof/service_instance'
require 'prof/cloud_foundry'
require 'prof/test_app'
require 'rabbitmq/http/client'

require "mqtt"
require "stomp"
require 'net/https'
require 'httparty'

require File.expand_path('../../../../system_test/test_app/lib/lab_rat/aggregate_health_checker.rb', __FILE__)

RSpec.describe 'Using a Cloud Foundry service broker' do
  let(:service_name) { environment.bosh_manifest.property('rabbitmq-broker.service.name') }

  let(:service) do
    Prof::MarketplaceService.new(
      name: service_name,
      plan: 'standard'
    )
  end

  let(:rmq_host) do
    bosh_director.ips_for_job("rmq", environment.bosh_manifest.deployment_name)[0]
  end

  let(:rmq_server_admin_broker_username) do
    environment.bosh_manifest.property('rabbitmq-server.administrators.broker.username')
  end

  let(:rmq_server_admin_broker_password) do
    environment.bosh_manifest.property('rabbitmq-server.administrators.broker.password')
  end

  let(:rmq_broker_username) do
    environment.bosh_manifest.property('broker.username')
  end

  let(:rmq_broker_password) do
    environment.bosh_manifest.property('broker.password')
  end

  let(:rmq_broker_host) do
    protocol = environment.bosh_manifest.property('broker.protocol')
    host = environment.bosh_manifest.property('broker.host')
    URI.parse("#{protocol}://#{host}")
  end

  let(:broker_catalog) do
    catalog_uri = URI.join(rmq_broker_host, '/v2/catalog')
    req = Net::HTTP::Get.new(catalog_uri)
    req.basic_auth(rmq_broker_username, rmq_broker_password)
    response = Net::HTTP.start(rmq_broker_host.hostname, rmq_broker_host.port, :use_ssl => rmq_broker_host.scheme == 'https', :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |http|
      http.request(req)
    end
    JSON.parse(response.body)
  end

  context 'default deployment'  do
    it 'provides default connectivity', :pushes_cf_app do
      cf.push_app_and_bind_with_service(test_app, service) do |app, _|
        provides_amqp_connectivity(app)
        provides_mqtt_connectivity(app)
        provides_stomp_connectivity(app)
      end
    end
  end

  context 'when stomp plugin is disabled'  do
    before(:context) do
      modify_and_deploy_manifest do |manifest|
        manifest['properties']['rabbitmq-server']['plugins'] = ['rabbitmq_management','rabbitmq_mqtt']
      end
    end

    after(:context) do
      bosh_director.deploy(environment.bosh_manifest.path)
    end

    it 'provides only amqp and mqtt connectivity', :pushes_cf_app do
      cf.push_app_and_bind_with_service(test_app, service) do |app, _|

        provides_amqp_connectivity(app)

        provides_mqtt_connectivity(app)

        provides_no_stomp_connectivity(app)
      end
    end
  end

  context 'when broker is configured with HA policy' do
    before(:context) do
      modify_and_deploy_manifest do |manifest|
        manifest['properties']['rabbitmq-broker']['rabbitmq']['operator_set_policy'] = {
          'enabled' => true,
          'policy_name' => "operator_set_policy",
          'policy_definition' => "{\"ha-mode\":\"exactly\",\"ha-params\":2,\"ha-sync-mode\":\"automatic\"}",
          'policy_priority' => 50
        }
      end
    end

    after(:context) do
      bosh_director.deploy(environment.bosh_manifest.path)
    end

    it 'sets queue policy to each created service instance', :pushes_cf_app do
      cf.push_app_and_bind_with_service(test_app, service) do |app, _|
        provides_mirrored_queue_policy_as_a_default(app)
      end
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

  context 'when broker is configured' do
    context 'when the service broker is configured with particular service metadata' do
      let(:service_info) { broker_catalog['services'].first }
      let(:broker_catalog_metadata) { service_info['metadata'] }

      before(:all) do
        modify_and_deploy_manifest do |manifest|
          service_properties = manifest['properties']['rabbitmq-broker']['service']
          service_properties['name'] = "service-name"
          service_properties['display_name'] = "apps-manager-test-name"
          service_properties['offering_description'] = "Some description of our service"
          service_properties['long_description'] = "Some long description of our service"
          service_properties['icon_image'] = "image-uri"
          service_properties['provider_display_name'] = "CompanyName"
          service_properties['documentation_url'] = "https://documentation.url"
          service_properties['support_url'] = "https://support.url"
        end
      end

      after(:all) do
        bosh_director.deploy(environment.bosh_manifest.path)
      end

      describe 'the catalog' do
        it 'has the correct name' do
          expect(service_info['name']).to eq("service-name")
        end

        it 'has the correct description' do
          expect(service_info['description']).to eq("Some description of our service")
        end

        it 'has the correct display name' do
          expect(broker_catalog_metadata['displayName']).to eq("apps-manager-test-name")
        end

        it 'has the correct long description' do
          expect(broker_catalog_metadata['longDescription']).to eq("Some long description of our service")
        end

        it 'has the correct image icon' do
          expect(broker_catalog_metadata['imageUrl']).to eq("data:image/png;base64,image-uri")
        end

        it 'has the correct provider display name' do
          expect(broker_catalog_metadata['providerDisplayName']).to eq("CompanyName")
        end

        it 'has the correct documentation url' do
          expect(broker_catalog_metadata['documentationUrl']).to eq("https://documentation.url")
        end

        it 'has the correct support url' do
          expect(broker_catalog_metadata['supportUrl']).to eq("https://support.url")
        end
      end
    end
  end
end



def get(url)
  HTTParty.get(url, {verify: false, timeout: 2})
end

def provides_amqp_connectivity(app)
  response = get("#{app.url}/services/rabbitmq/protocols/amqp091")
  expect(response.code).to eql(200)
  expect(response.body).to include('amq.gen')
end

def provides_mqtt_connectivity(app)
  response = get("#{app.url}/services/rabbitmq/protocols/mqtt")

  expect(response.code).to eql(200)
  expect(response.body).to include('mqtt://')
  expect(response.body).to include('Payload published')

  queues = ssh_gateway.execute_on(rmq_host, "curl -u #{rmq_server_admin_broker_username}:#{rmq_server_admin_broker_password} http://#{rmq_host}:15672/api/queues -s")
  json = JSON.parse(queues)
  json.select!{ |queue| queue["name"] == "mqtt-subscription-mqtt_test_clientqos1" }
  expect(json.length).to eql(1)
  expect(json[0]["arguments"]["x-expires"]).to eql(1800000)
end

def provides_stomp_connectivity(app)
  response = get("#{app.url}/services/rabbitmq/protocols/stomp")

  expect(response.code).to eql(200)
  expect(response.body).to include('Payload published')
end

def provides_no_stomp_connectivity(app)
  response = get("#{app.url}/services/rabbitmq/protocols/stomp")

  expect(response.code).to eql(500)
end


def provides_direct_amqp_connectivity(service_key_data)
  amqp_proto = service_key_data['protocols']['amqp'].dup

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
  service_protocols = credentials[service_name].first['credentials']['protocols']

  management_credentials_key = service_protocols.keys.detect { |k| k =~ /^management/ }
  management_credentials = service_protocols[management_credentials_key]

  ssh_gateway.with_port_forwarded_to(management_credentials['host'], management_credentials['port']) do |port|
    endpoint = "http://localhost:#{port}"

    client = RabbitMQ::HTTP::Client.new(endpoint,
                                        username: management_credentials['username'],
                                        password: management_credentials['password'],
                                        ssl: {
                                          verify: false
                                        })

    amqp_vhost_key = service_protocols.keys.detect { |k| k =~ /^amqp/ }
    vhost = service_protocols[amqp_vhost_key]['vhost']

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

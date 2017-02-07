require 'spec_helper'

require 'json'
require 'mqtt'

require 'hula'
require 'hula/bosh_manifest'
require 'prof/marketplace_service'
require 'prof/service_instance'
require 'prof/cloud_foundry'
require 'prof/test_app'

RSpec.describe "logging configuration" do
  RMQ_Z1_HOST = bosh_director.ips_for_job("rmq", environment.bosh_manifest.deployment_name)[0]
  RMQ_Z2_HOST = bosh_director.ips_for_job("rmq", environment.bosh_manifest.deployment_name)[1]
  RMQ_Z3_HOST = bosh_director.ips_for_job("rmq", environment.bosh_manifest.deployment_name)[2]
  HAPROXY_HOST = bosh_director.ips_for_job("haproxy", environment.bosh_manifest.deployment_name)[0]

  HAPROXY_LOG_LOCATION = "/var/vcap/sys/log/rabbitmq-haproxy/haproxy.log"

  RMQ_HOST_Z1_DIGEST = Digest::MD5.hexdigest(RMQ_Z1_HOST)
  RMQ_HOST_Z2_DIGEST = Digest::MD5.hexdigest(RMQ_Z2_HOST)
  RMQ_HOST_Z3_DIGEST = Digest::MD5.hexdigest(RMQ_Z3_HOST)

  SERVICE_NAME = environment.bosh_manifest.property('rabbitmq-broker.service.name')
  SERVICE = Prof::MarketplaceService.new(
    name: SERVICE_NAME,
    plan: 'standard'
  )

  context "when a connection is made over AMQP" do
    before :context do
      ssh_gateway.execute_on(RMQ_Z1_HOST, "cp /var/vcap/sys/log/rabbitmq-server/rabbit@#{RMQ_HOST_Z1_DIGEST}.log /tmp")
      ssh_gateway.execute_on(RMQ_Z2_HOST, "cp /var/vcap/sys/log/rabbitmq-server/rabbit@#{RMQ_HOST_Z2_DIGEST}.log /tmp")
      ssh_gateway.execute_on(RMQ_Z3_HOST, "cp /var/vcap/sys/log/rabbitmq-server/rabbit@#{RMQ_HOST_Z3_DIGEST}.log /tmp")

      ssh_gateway.execute_on(RMQ_Z1_HOST, "> /var/vcap/sys/log/rabbitmq-server/rabbit@#{RMQ_HOST_Z1_DIGEST}.log")
      ssh_gateway.execute_on(RMQ_Z2_HOST, "> /var/vcap/sys/log/rabbitmq-server/rabbit@#{RMQ_HOST_Z2_DIGEST}.log")
      ssh_gateway.execute_on(RMQ_Z3_HOST, "> /var/vcap/sys/log/rabbitmq-server/rabbit@#{RMQ_HOST_Z3_DIGEST}.log")

    end

    after :context do
      ssh_gateway.execute_on(RMQ_Z1_HOST, "cp /tmp/rabbit@#{RMQ_HOST_Z1_DIGEST}.log /var/vcap/sys/log/rabbitmq-server")
      ssh_gateway.execute_on(RMQ_Z2_HOST, "cp /tmp/rabbit@#{RMQ_HOST_Z2_DIGEST}.log /var/vcap/sys/log/rabbitmq-server")
      ssh_gateway.execute_on(RMQ_Z3_HOST, "cp /tmp/rabbit@#{RMQ_HOST_Z3_DIGEST}.log /var/vcap/sys/log/rabbitmq-server")
    end

    it "logs an AMQP connection acceptance at INFO level to rabbitmq server logs", :pushes_cf_app do
      cf.push_app_and_bind_with_service(test_app, SERVICE) do |app, _|
        uri = URI("#{app.url}/services/rabbitmq/protocols/amqp091")

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        http.request_get(uri.request_uri)
      end
      rabbitmq_server1_log = ssh_gateway.execute_on(RMQ_Z1_HOST, "cat /var/vcap/sys/log/rabbitmq-server/rabbit@#{RMQ_HOST_Z1_DIGEST}.log")
      rabbitmq_server2_log = ssh_gateway.execute_on(RMQ_Z2_HOST, "cat /var/vcap/sys/log/rabbitmq-server/rabbit@#{RMQ_HOST_Z2_DIGEST}.log")
      rabbitmq_server3_log = ssh_gateway.execute_on(RMQ_Z3_HOST, "cat /var/vcap/sys/log/rabbitmq-server/rabbit@#{RMQ_HOST_Z3_DIGEST}.log")

      expect(rabbitmq_server1_log + rabbitmq_server2_log + rabbitmq_server3_log).to include "accepting AMQP connection"
    end
  end

  context "when a connection is made over HAProxy" do
    before :context do
      ssh_gateway.execute_on(HAPROXY_HOST, "cp #{HAPROXY_LOG_LOCATION} /tmp")
      ssh_gateway.execute_on(HAPROXY_HOST, "> #{HAPROXY_LOG_LOCATION}")

      ssh_gateway.execute_on(HAPROXY_HOST, "curl localhost:15672")
    end

    after :context do
      ssh_gateway.execute_on(HAPROXY_HOST, "cp /tmp/haproxy.log #{HAPROXY_LOG_LOCATION}")
      ssh_gateway.execute_on(HAPROXY_HOST, "rm /tmp/haproxy.log")
    end

    it "logs an entry to the haproxy logs" do
      haproxy_log = ssh_gateway.execute_on(HAPROXY_HOST, "cat #{HAPROXY_LOG_LOCATION}")
      expect(haproxy_log).to include "input-15672 output-15672/node"
    end
  end
end

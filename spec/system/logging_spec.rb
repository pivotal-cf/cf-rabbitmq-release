require 'spec_helper'

require 'json'
require 'mqtt'

require 'hula'
require 'hula/bosh_manifest'

describe "logging configuration" do

  RMQ_Z1_JOB_NAME = "rmq_z1"
  RMQ_Z2_JOB_NAME = "rmq_z2"
  HAPROXY_JOB_NAME = "haproxy_z1"
  BOSH_JOB_INDEX = 0
  RMQ_Z1_HOST = bosh_director.ips_for_job(RMQ_Z1_JOB_NAME, environment.bosh_manifest.deployment_name)[BOSH_JOB_INDEX]
  RMQ_Z2_HOST = bosh_director.ips_for_job(RMQ_Z2_JOB_NAME, environment.bosh_manifest.deployment_name)[BOSH_JOB_INDEX]
  HAPROXY_HOST = bosh_director.ips_for_job(HAPROXY_JOB_NAME, environment.bosh_manifest.deployment_name)[BOSH_JOB_INDEX]

  HAPROXY_LOG_LOCATION = "/var/vcap/sys/log/rabbitmq-haproxy/haproxy.log"

  RMQ_HOST_Z1_DIGEST = Digest::MD5.hexdigest(RMQ_Z1_HOST)
  RMQ_HOST_Z2_DIGEST = Digest::MD5.hexdigest(RMQ_Z2_HOST)

  context "when a connection is made and broken over MQTT" do
    before :context do
      ssh_gateway.execute_on(RMQ_Z1_HOST, "cp /var/vcap/sys/log/rabbitmq-server/rabbit@#{RMQ_HOST_Z1_DIGEST}.log /tmp")
      ssh_gateway.execute_on(RMQ_Z2_HOST, "cp /var/vcap/sys/log/rabbitmq-server/rabbit@#{RMQ_HOST_Z2_DIGEST}.log /tmp")

      ssh_gateway.execute_on(RMQ_Z1_HOST, "> /var/vcap/sys/log/rabbitmq-server/rabbit@#{RMQ_HOST_Z1_DIGEST}.log")
      ssh_gateway.execute_on(RMQ_Z2_HOST, "> /var/vcap/sys/log/rabbitmq-server/rabbit@#{RMQ_HOST_Z2_DIGEST}.log")

      # Try to create an MQTT connection to generate INFO and ERROR logs
      expect {
        MQTT::Client.connect(:remote_host => HAPROXY_HOST, :port => 1883)
      }.to raise_error(MQTT::ProtocolException)
    end

    after :context do
      ssh_gateway.execute_on(RMQ_Z1_HOST, "cp /tmp/rabbit@#{RMQ_HOST_Z1_DIGEST}.log /var/vcap/sys/log/rabbitmq-server")
      ssh_gateway.execute_on(RMQ_Z2_HOST, "cp /tmp/rabbit@#{RMQ_HOST_Z2_DIGEST}.log /var/vcap/sys/log/rabbitmq-server")
    end

    it "logs an MQTT connection acceptance at INFO level to rabbitmq server logs" do
      rabbitmq_server1_log = ssh_gateway.execute_on(RMQ_Z1_HOST, "cat /var/vcap/sys/log/rabbitmq-server/rabbit@#{RMQ_HOST_Z1_DIGEST}.log")
      rabbitmq_server2_log = ssh_gateway.execute_on(RMQ_Z2_HOST, "cat /var/vcap/sys/log/rabbitmq-server/rabbit@#{RMQ_HOST_Z2_DIGEST}.log")

      expect(rabbitmq_server1_log + rabbitmq_server2_log).to include "accepting MQTT connection"
    end

    it "logs a failed MQTT login at ERROR level to rabbitmq server logs" do
      rabbitmq_server1_log = ssh_gateway.execute_on(RMQ_Z1_HOST, "cat /var/vcap/sys/log/rabbitmq-server/rabbit@#{RMQ_HOST_Z1_DIGEST}.log")
      rabbitmq_server2_log = ssh_gateway.execute_on(RMQ_Z2_HOST, "cat /var/vcap/sys/log/rabbitmq-server/rabbit@#{RMQ_HOST_Z2_DIGEST}.log")

      expect(rabbitmq_server1_log + rabbitmq_server2_log).to include "MQTT login failed for \"guest\" auth_failure: Refused"
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

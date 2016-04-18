require 'spec_helper'

require 'json'

require 'hula'
require 'hula/bosh_manifest'

RSpec.describe "Syslog forwarding" do

  RMQ_JOB_NAME = "rmq_z1"
  BROKER_JOB_NAME = "rmq-broker"
  HAPROXY_JOB_NAME = "haproxy_z1"
  BOSH_JOB_INDEX = 0
  RMQ_HOST = bosh_director.ips_for_job(RMQ_JOB_NAME, environment.bosh_manifest.deployment_name)[BOSH_JOB_INDEX]
  BROKER_HOST = bosh_director.ips_for_job(BROKER_JOB_NAME, environment.bosh_manifest.deployment_name)[BOSH_JOB_INDEX]
  HAPROXY_HOST = bosh_director.ips_for_job(HAPROXY_JOB_NAME, environment.bosh_manifest.deployment_name)[BOSH_JOB_INDEX]

  SYSLOG_ADDRESS = "127.0.0.1"
  SYSLOG_PORT = 12345
  NC_COMMAND = "nc -k -l #{SYSLOG_ADDRESS} #{SYSLOG_PORT}"

  RMQ_ADMIN_BROKER_USERNAME = environment.bosh_manifest.property("rabbitmq-server.administrators.broker.username")
  RMQ_ADMIN_BROKER_PASSWORD = environment.bosh_manifest.property("rabbitmq-server.administrators.broker.password")

  context "when the syslog forwarder properties are set in the BOSH manifest" do
    before :context do
      @rmq_listener_thread = create_listener_thread(RMQ_HOST)
      @broker_listener_thread = create_listener_thread(BROKER_HOST)
      @haproxy_listener_thread = create_listener_thread(HAPROXY_HOST)

      modify_and_deploy_manifest do |manifest|
        manifest["properties"]["syslog_aggregator"] = { "address" => SYSLOG_ADDRESS, "port" => SYSLOG_PORT }
      end
    end

    after :context do
      @rmq_listener_thread.kill
      @broker_listener_thread.kill
      @haproxy_listener_thread.kill

      ssh_gateway.execute_on(RMQ_HOST, "pkill -f '#{NC_COMMAND}'")
      ssh_gateway.execute_on(BROKER_HOST, "pkill -f '#{NC_COMMAND}'")
      ssh_gateway.execute_on(HAPROXY_HOST, "pkill -f '#{NC_COMMAND}'")
      bosh_director.deploy(environment.bosh_manifest.path)
    end

    it "should forward the RabbitMQ server logs" do
        # Hit the HTTP Management endpoint to generate access log
        ssh_gateway.execute_on(RMQ_HOST, "curl -u #{RMQ_ADMIN_BROKER_USERNAME}:#{RMQ_ADMIN_BROKER_PASSWORD} http://#{RMQ_HOST}:15672/api/overview -s")

        # Generate some logs in the shutdown_err files to test against.
        # These files are empty at normal startup/shutdown.
        ssh_gateway.execute_on(RMQ_HOST, "echo 'This is a test stdout log' >> /var/vcap/sys/log/rabbitmq-server/shutdown_stdout.log")
        ssh_gateway.execute_on(RMQ_HOST, "echo 'This is a test stderr log' >> /var/vcap/sys/log/rabbitmq-server/shutdown_stderr.log")

        output = ssh_gateway.execute_on(RMQ_HOST, "cat log.txt")

        expect(output).to include "rabbitmq_startup_stdout [job=#{RMQ_JOB_NAME} index=#{BOSH_JOB_INDEX}]"
        expect(output).to include "rabbitmq_startup_stderr [job=#{RMQ_JOB_NAME} index=#{BOSH_JOB_INDEX}]"
        expect(output).to include "rabbitmq [job=#{RMQ_JOB_NAME} index=#{BOSH_JOB_INDEX}]"

        expect(output).to include "rabbitmq_http_api_access [job=#{RMQ_JOB_NAME} index=#{BOSH_JOB_INDEX}]"

        expect(output).to include "rabbitmq_shutdown_stdout [job=#{RMQ_JOB_NAME} index=#{BOSH_JOB_INDEX}] This is a test stdout log"
        expect(output).to include "rabbitmq_shutdown_stderr [job=#{RMQ_JOB_NAME} index=#{BOSH_JOB_INDEX}] This is a test stderr log"
    end

    it "should forward the Service Broker logs" do
        # Generate some logs in the shutdown_err files to test against.
        # These files are empty at normal startup/shutdown.
        ssh_gateway.execute_on(BROKER_HOST, "echo 'This is a test log' >> /var/vcap/sys/log/management-route-registrar/route-registrar.stderr.log")
        ssh_gateway.execute_on(BROKER_HOST, "echo 'This is a test log' >> /var/vcap/sys/log/broker-route-registrar/route-registrar.stderr.log")

        output = ssh_gateway.execute_on(BROKER_HOST, "cat log.txt")

        expect(output).to include "rabbitmq-service-broker_startup_stdout [job=#{BROKER_JOB_NAME} index=#{BOSH_JOB_INDEX}]"
        expect(output).to include "rabbitmq-service-broker_startup_stderr [job=#{BROKER_JOB_NAME} index=#{BOSH_JOB_INDEX}]"
        expect(output).to include "rabbitmq-management-route-registrar_stdout [job=#{BROKER_JOB_NAME} index=#{BOSH_JOB_INDEX}]"
        expect(output).to include "rabbitmq-management-route-registrar_stderr [job=#{BROKER_JOB_NAME} index=#{BOSH_JOB_INDEX}]"
        expect(output).to include "rabbitmq-service-broker-route-registrar_stdout [job=#{BROKER_JOB_NAME} index=#{BOSH_JOB_INDEX}]"
        expect(output).to include "rabbitmq-service-broker-route-registrar_stderr [job=#{BROKER_JOB_NAME} index=#{BOSH_JOB_INDEX}]"
      end

      it "should forward the haproxy logs" do
        ssh_gateway.execute_on(HAPROXY_HOST, "curl localhost")

        output_from_syslog = ssh_gateway.execute_on(HAPROXY_HOST, "cat log.txt")
        output_from_file = ssh_gateway.execute_on(HAPROXY_HOST, "cat /var/vcap/sys/log/rabbitmq-haproxy/haproxy.log")

        expect(output_from_syslog).to include "rabbitmq-haproxy_haproxy_log [job=#{HAPROXY_JOB_NAME} index=#{BOSH_JOB_INDEX}]"
        expect(output_from_file).to include "localhost haproxy"
      end
  end
end

def create_listener_thread(host)
  Thread.new do
    ssh_gateway.execute_on(host, "rm log.txt")
    ssh_gateway.execute_on(host, "pkill -f '#{NC_COMMAND}'")
    ssh_gateway.execute_on(host, "#{NC_COMMAND} > log.txt")
  end
end

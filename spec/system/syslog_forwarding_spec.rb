require 'spec_helper'
require 'hula'
require 'hula/bosh_manifest'

RSpec.describe "Syslog forwarding" do

  before(:all) do
    @rmq_job_name = 'rmq'
    @broker_job_name = "rmq-broker"
    @haproxy_job_name = "haproxy"
    @bosh_job_index = 0
    @rmq_host = bosh_director.ips_for_job(@rmq_job_name, environment.bosh_manifest.deployment_name)[@bosh_job_index]
    @broker_host = bosh_director.ips_for_job(@broker_job_name, environment.bosh_manifest.deployment_name)[@bosh_job_index]
    @haproxy_host = bosh_director.ips_for_job(@haproxy_job_name, environment.bosh_manifest.deployment_name)[@bosh_job_index]

    @syslog_address = "127.0.0.1"
    @syslog_port = 12345
    @nc_command = "nc -k -l #{@syslog_address} #{@syslog_port}"

    @rmq_admin_broker_username = environment.bosh_manifest.property("rabbitmq-server.administrators.broker.username")
    @rmq_admin_broker_password = environment.bosh_manifest.property("rabbitmq-server.administrators.broker.password")
  end

  context "when the syslog forwarder properties are set in the BOSH manifest" do
    before :context do
      @rmq_listener_thread = create_listener_thread(@rmq_host)
      @broker_listener_thread = create_listener_thread(@broker_host)
      @haproxy_listener_thread = create_listener_thread(@haproxy_host)

      modify_and_deploy_manifest do |manifest|
        manifest["properties"]["syslog_aggregator"] = { "address" => @syslog_address, "port" => @syslog_port }
      end
    end

    after :context do
      @rmq_listener_thread.kill
      @broker_listener_thread.kill
      @haproxy_listener_thread.kill

      ssh_gateway.execute_on(@rmq_host, "pkill -f '#{@nc_command}'")
      ssh_gateway.execute_on(@broker_host, "pkill -f '#{@nc_command}'")
      ssh_gateway.execute_on(@haproxy_host, "pkill -f '#{@nc_command}'")
      bosh_director.deploy(environment.bosh_manifest.path)
    end

    it "should forward the RabbitMQ server logs" do
      # Hit the HTTP Management endpoint to generate access log
      ssh_gateway.execute_on(@rmq_host, "curl -u #{@rmq_admin_broker_username}:#{@rmq_admin_broker_password} http://#{@rmq_host}:15672/api/overview -s")

      # Generate some logs in the shutdown_err files to test against.
      # These files are empty at normal startup/shutdown.
      ssh_gateway.execute_on(@rmq_host, "echo 'This is a test stdout log' >> /var/vcap/sys/log/rabbitmq-server/shutdown_stdout.log")
      ssh_gateway.execute_on(@rmq_host, "echo 'This is a test stderr log' >> /var/vcap/sys/log/rabbitmq-server/shutdown_stderr.log")

      output = ssh_gateway.execute_on(@rmq_host, "cat log.txt")
      expect(output).to include "rabbitmq_startup_stdout [job=#{@rmq_job_name} index=#{@bosh_job_index}]"
      expect(output).to include "rabbitmq_startup_stderr [job=#{@rmq_job_name} index=#{@bosh_job_index}]"
      expect(output).to include "rabbitmq [job=#{@rmq_job_name} index=#{@bosh_job_index}]"

      expect(output).to include "rabbitmq_http_api_access [job=#{@rmq_job_name} index=#{@bosh_job_index}]"

      expect(output).to include "rabbitmq_shutdown_stdout [job=#{@rmq_job_name} index=#{@bosh_job_index}] This is a test stdout log"
      expect(output).to include "rabbitmq_shutdown_stderr [job=#{@rmq_job_name} index=#{@bosh_job_index}] This is a test stderr log"
    end

    it "should forward the Service Broker logs" do
      # Generate some logs in the shutdown_err files to test against.
      # These files are empty at normal startup/shutdown.
      ssh_gateway.execute_on(@broker_host, "echo 'This is a test log' >> /var/vcap/sys/log/route_registrar/route_registrar.err.log")

      output = ssh_gateway.execute_on(@broker_host, "cat log.txt")

      expect(output).to include "rabbitmq-service-broker_startup_stdout [job=#{@broker_job_name} index=#{@bosh_job_index}]"
      expect(output).to include "rabbitmq-service-broker_startup_stderr [job=#{@broker_job_name} index=#{@bosh_job_index}]"

      expect(output).to include "rabbitmq-service-broker-route_registrar_stdout [job=#{@broker_job_name} index=#{@bosh_job_index}]"
      expect(output).to include "rabbitmq-service-broker-route_registrar_stderr [job=#{@broker_job_name} index=#{@bosh_job_index}]"
    end

    it "should forward the haproxy logs" do
      ssh_gateway.execute_on(@haproxy_host, "curl localhost")

      # Generate some logs in the shutdown_err files to test against.
      # These files are empty at normal startup/shutdown.
      ssh_gateway.execute_on(@haproxy_host, "echo 'This is a test log' >> /var/vcap/sys/log/route_registrar/route_registrar.err.log")

      output_from_syslog = ssh_gateway.execute_on(@haproxy_host, "cat log.txt")
      output_from_file = ssh_gateway.execute_on(@haproxy_host, "cat /var/vcap/sys/log/rabbitmq-haproxy/haproxy.log")

      expect(output_from_syslog).to include "rabbitmq-haproxy_haproxy_log [job=#{@haproxy_job_name} index=#{@bosh_job_index}]"
      expect(output_from_file).to include "localhost haproxy"

      expect(output_from_syslog).to include "rabbitmq-haproxy-route_registrar_stdout [job=#{@haproxy_job_name} index=#{@bosh_job_index}]"
      expect(output_from_syslog).to include "rabbitmq-haproxy-route_registrar_stderr [job=#{@haproxy_job_name} index=#{@bosh_job_index}]"
    end
  end
end

def create_listener_thread(host)
  Thread.new do
    ssh_gateway.execute_on(host, "rm log.txt")
    ssh_gateway.execute_on(host, "pkill -f '#{@nc_command}'")
    ssh_gateway.execute_on(host, "#{@nc_command} > log.txt")
  end
end

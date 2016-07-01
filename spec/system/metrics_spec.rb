require 'spec_helper'
require 'date'

RSpec.describe 'metrics', :metrics => true do
  describe 'rabbitmq haproxy metrics, rabbitmq server metrics, and broker metrics' do
    before(:all) do
      @haproxy_z1_host = bosh_director.ips_for_job('haproxy_z1', environment.bosh_manifest.deployment_name)[0]
      @rmq_z1_host = bosh_director.ips_for_job('rmq_z1', environment.bosh_manifest.deployment_name)[0]
      @rmq_z2_host = bosh_director.ips_for_job('rmq_z2', environment.bosh_manifest.deployment_name)[0]
      @rmq_broker_host = bosh_director.ips_for_job('rmq-broker', environment.bosh_manifest.deployment_name)[0]
    end

    context 'when all the services are up' do
      before(:all) do
        @firehose = Matchers::Firehose.new(doppler_address: doppler_address, access_token: cf.auth_token)
        ssh_gateway.execute_on(@haproxy_z1_host, '/var/vcap/bosh/bin/monit start rabbitmq-haproxy', :root => true)
        ssh_gateway.execute_on(@rmq_z1_host, '/var/vcap/bosh/bin/monit start rabbitmq-server', :root => true)
        ssh_gateway.execute_on(@rmq_z2_host, '/var/vcap/bosh/bin/monit start rabbitmq-server', :root => true)
        ssh_gateway.execute_on(@rmq_broker_host, '/var/vcap/bosh/bin/monit start rabbitmq-broker', :root => true)

        wait_for(job: @haproxy_z1_host, status: 'running')
        wait_for(job: @rmq_z1_host, status: 'running')
        wait_for(job: @rmq_z2_host, status: 'running')
        wait_for(job: @rmq_broker_host, status: 'running')
      end

      it 'contains haproxy_z1 metrics' do
        metrics_regexp_pattern = [
          /name:"\/p-rabbitmq\/haproxy\/heartbeat" value:1 unit:"boolean"/,
          /name:"\/p-rabbitmq\/haproxy\/health\/connections" value:\d+ unit:"count"/,
          /name:"\/p-rabbitmq\/haproxy\/backend\/qsize\/amqp" value:\d+ unit:"size"/,
          /name:"\/p-rabbitmq\/haproxy\/backend\/retries\/amqp" value:\d+ unit:"count"/,
          /name:"\/p-rabbitmq\/haproxy\/backend\/ctime\/amqp" value:\d+ unit:"time"/
        ]
        expect(@firehose).to have_metrics('haproxy_z1', 0, metrics_regexp_pattern)
      end

      it 'contains rmq_z1 node metrics' do
        metrics_regexp_pattern = [
          /name:"\/p-rabbitmq\/rabbitmq\/system\/memory" .* unit:"MB"/,
          /name:"\/p-rabbitmq\/rabbitmq\/erlang\/erlang_processes" value:[1-9][0-9]* unit:"count"/,
          /name:"\/p-rabbitmq\/rabbitmq\/heartbeat" value:1 unit:"boolean"/
        ]
        expect(@firehose).to have_metrics('rmq_z1', 0, metrics_regexp_pattern)
      end

      it 'contains rmq_z2 node metrics' do
        metrics_regexp_pattern = [
          /name:"\/p-rabbitmq\/rabbitmq\/system\/memory" .* unit:"MB"/,
          /name:"\/p-rabbitmq\/rabbitmq\/erlang\/erlang_processes" value:[1-9][0-9]* unit:"count"/,
          /name:"\/p-rabbitmq\/rabbitmq\/heartbeat" value:1 unit:"boolean"/
        ]
        expect(@firehose).to have_metrics('rmq_z2', 0, metrics_regexp_pattern)
      end

      it 'contains rmq-broker node metrics' do
        expect(@firehose).to have_metrics('rmq-broker', 0, [/name:"\/p-rabbitmq\/service_broker\/heartbeat" value:1 unit:"boolean"/])
      end
    end

    context 'when all the services are down' do
      before(:all) do
        ssh_gateway.execute_on(@haproxy_z1_host, '/var/vcap/bosh/bin/monit stop rabbitmq-haproxy', :root => true)
        ssh_gateway.execute_on(@rmq_z1_host, '/var/vcap/bosh/bin/monit stop rabbitmq-server', :root => true)
        ssh_gateway.execute_on(@rmq_z2_host, '/var/vcap/bosh/bin/monit stop rabbitmq-server', :root => true)
        ssh_gateway.execute_on(@rmq_broker_host, '/var/vcap/bosh/bin/monit stop rabbitmq-broker', :root => true)

        wait_for(job: @haproxy_z1_host, status: 'not monitored$')
        wait_for(job: @rmq_z1_host, status: 'not monitored$')
        wait_for(job: @rmq_z2_host, status: 'not monitored$')
        wait_for(job: @rmq_broker_host, status: 'not monitored$')

        @firehose = Matchers::Firehose.new(doppler_address: doppler_address, access_token: cf.auth_token)
      end

      after(:all) do
        ssh_gateway.execute_on(@haproxy_z1_host, '/var/vcap/bosh/bin/monit start rabbitmq-haproxy', :root => true)
        ssh_gateway.execute_on(@rmq_z1_host, '/var/vcap/bosh/bin/monit start rabbitmq-server', :root => true)
        ssh_gateway.execute_on(@rmq_z2_host, '/var/vcap/bosh/bin/monit start rabbitmq-server', :root => true)
        ssh_gateway.execute_on(@rmq_broker_host, '/var/vcap/bosh/bin/monit start rabbitmq-broker', :root => true)

        wait_for(job: @haproxy_z1_host, status: 'running')
        wait_for(job: @rmq_z1_host, status: 'running')
        wait_for(job: @rmq_z2_host, status: 'running')
        wait_for(job: @rmq_broker_host, status: 'running')
      end

      it 'contains haproxy_z1 heartbeat metrics for rabbitmq haproxy nodes' do
        expect(@firehose).to have_metrics('haproxy_z1', 0, [/name:"\/p-rabbitmq\/haproxy\/heartbeat" value:0 unit:"boolean"/])
      end

      it 'contains rmq_z1 node metrics' do
        metric_regex_pattern = [
          /name:"\/p-rabbitmq\/rabbitmq\/heartbeat" value:0 unit:"boolean"/,
          /name:"\/p-rabbitmq\/rabbitmq\/erlang\/erlang_processes" value:0 unit:"count"/
        ]
        expect(@firehose).to have_metrics('rmq_z1', 0, metric_regex_pattern)
      end

      it 'contains rmq_z2 node metrics' do
        metric_regex_pattern = [
          /name:"\/p-rabbitmq\/rabbitmq\/heartbeat" value:0 unit:"boolean"/,
          /name:"\/p-rabbitmq\/rabbitmq\/erlang\/erlang_processes" value:0 unit:"count"/
        ]
        expect(@firehose).to have_metrics('rmq_z2', 0, metric_regex_pattern)
      end

      it 'contains rmq-broker node metrics' do
        expect(@firehose).to have_metrics('rmq-broker', 0, [/name:"\/p-rabbitmq\/service_broker\/heartbeat" value:0 unit:"boolean"/])
      end

      it 'does not contain haproxy_z1 1 amqp health connection metric' do
        metric_regex_pattern = [
          /name:"\/p-rabbitmq\/haproxy\/health\/connections" value:\d+ unit:"count"/,
          /name:"\/p-rabbitmq\/haproxy\/backend\/qsize\/amqp" value:\d+ unit:"size"/,
          /name:"\/p-rabbitmq\/haproxy\/backend\/retries\/amqp" value:\d+ unit:"count"/,
          /name:"\/p-rabbitmq\/haproxy\/backend\/ctime\/amqp" value:\d+ unit:"time"/
        ]
        expect(@firehose).to have_not_metrics('haproxy_z1', 0, metric_regex_pattern, polling_interval: 60)
      end

    end
  end
end

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
        ssh_gateway.execute_on(@haproxy_z1_host, '/var/vcap/bosh/bin/monit start rabbitmq-haproxy', :root => true)
        ssh_gateway.execute_on(@rmq_z1_host, '/var/vcap/bosh/bin/monit start rabbitmq-server', :root => true)
        ssh_gateway.execute_on(@rmq_z2_host, '/var/vcap/bosh/bin/monit start rabbitmq-server', :root => true)
        ssh_gateway.execute_on(@rmq_broker_host, '/var/vcap/bosh/bin/monit start rabbitmq-broker', :root => true)

        wait_for(job: @haproxy_z1_host, status: 'running')
        wait_for(job: @rmq_z1_host, status: 'running')
        wait_for(job: @rmq_z2_host, status: 'running')
        wait_for(job: @rmq_broker_host, status: 'running')

        @firehose = Matchers::Firehose.new(doppler_address: doppler_address, access_token: cf.auth_token)
      end

      after(:all) do
        @firehose.close
      end

      it 'contains haproxy_z1 heartbeat metric for rabbitmq haproxy nodes' do
        expect(@firehose).to have_metric('haproxy_z1', 0, /name:"\/p-rabbitmq\/haproxy\/heartbeat" value:1 unit:"boolean"/)
      end

      it 'contains haproxy_z1 amqp health connection metrics' do
        regexp_pattern = 'name:"\/p-rabbitmq\/haproxy\/health\/connections" value:\d+ unit:"count"'
        expect(@firehose).to have_metric('haproxy_z1', 0, Regexp.new(regexp_pattern))
      end

      it 'contains haproxy_z1 amqp queue size' do
        expect(@firehose).to have_metric('haproxy_z1', 0, /name:"\/p-rabbitmq\/haproxy\/backend\/qsize\/amqp" value:\d+ unit:"size"/)
      end

      it 'contains haproxy_z1 amqp retries' do
        expect(@firehose).to have_metric('haproxy_z1', 0, /name:"\/p-rabbitmq\/haproxy\/backend\/retries\/amqp" value:\d+ unit:"count"/)
      end

      it 'contains haproxy_z1 amqp connection time' do
        expect(@firehose).to have_metric('haproxy_z1', 0, /name:"\/p-rabbitmq\/haproxy\/backend\/ctime\/amqp" value:\d+ unit:"time"/)
      end

      it 'contains system memory' do
        expect(@firehose).to have_metric('rmq_z1', 0, /name:"\/p-rabbitmq\/rabbitmq\/system\/memory" .* unit:"MB"/)
        expect(@firehose).to have_metric('rmq_z2', 0, /name:"\/p-rabbitmq\/rabbitmq\/system\/memory" .* unit:"MB"/)
      end

      it 'contains erlang process count metrics for all RabbitMQ nodes' do
        expect(@firehose).to have_metric('rmq_z1', 0, /name:"\/p-rabbitmq\/rabbitmq\/erlang\/erlang_processes" value:[1-9][0-9]* unit:"count"/)
        expect(@firehose).to have_metric('rmq_z2', 0, /name:"\/p-rabbitmq\/rabbitmq\/erlang\/erlang_processes" value:[1-9][0-9]* unit:"count"/)
      end

      it 'contains the heartbeat metrics for all RabbitMQ nodes' do
        expect(@firehose).to have_metric('rmq_z1', 0, /name:"\/p-rabbitmq\/rabbitmq\/heartbeat" value:1 unit:"boolean"/)
        expect(@firehose).to have_metric('rmq_z2', 0, /name:"\/p-rabbitmq\/rabbitmq\/heartbeat" value:1 unit:"boolean"/)
      end

      it 'contains the system file_descriptors metric' do
        expect(@firehose).to have_metric('rmq_z1', 0, /name:"\/p-rabbitmq\/rabbitmq\/system\/file_descriptors" value:\d+ unit:"count"/)
        expect(@firehose).to have_metric('rmq_z2', 0, /name:"\/p-rabbitmq\/rabbitmq\/system\/file_descriptors" value:\d+ unit:"count"/)
      end

      it 'contains rmq-broker node metrics' do
        expect(@firehose).to have_metric('rmq-broker', 0, /name:"\/p-rabbitmq\/service_broker\/heartbeat" value:1 unit:"boolean"/)
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
        @firehose.close

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
        expect(@firehose).to have_metric('haproxy_z1', 0, /name:"\/p-rabbitmq\/haproxy\/heartbeat" value:0 unit:"boolean"/)
      end

      it 'contains rmq_z1 and rmq_z2 heartbeat node metrics' do
        expect(@firehose).to have_metric('rmq_z1', 0, /name:"\/p-rabbitmq\/rabbitmq\/heartbeat" value:0 unit:"boolean"/)
        expect(@firehose).to have_metric('rmq_z2', 0, /name:"\/p-rabbitmq\/rabbitmq\/heartbeat" value:0 unit:"boolean"/)
      end

      it 'contains rmq_z1 and rmq_z2 process count metrics' do
        expect(@firehose).to have_metric('rmq_z1', 0, /name:"\/p-rabbitmq\/rabbitmq\/erlang\/erlang_processes" value:0 unit:"count"/)
        expect(@firehose).to have_metric('rmq_z2', 0, /name:"\/p-rabbitmq\/rabbitmq\/erlang\/erlang_processes" value:0 unit:"count"/)
      end

      it 'contains rmq-broker node metrics' do
        expect(@firehose).to have_metric('rmq-broker', 0, /name:"\/p-rabbitmq\/service_broker\/heartbeat" value:0 unit:"boolean"/)
      end

      it 'does not contain haproxy_z1 1 amqp health connection metric' do
        expect(@firehose).to_not have_metric('haproxy_z1', 0, /name:"\/p-rabbitmq\/haproxy\/health\/connections" value:\d+ unit:"count"/, polling_interval: 60)
      end

      it 'does not contain haproxy_z1 amqp queue size' do
        expect(@firehose).to_not have_metric('haproxy_z1', 0, /name:"\/p-rabbitmq\/haproxy\/backend\/qsize\/amqp" value:\d+ unit:"size"/, polling_interval: 60)
      end

      it 'does not contain haproxy_z1 amqp retries' do
        expect(@firehose).to_not have_metric('haproxy_z1', 0, /name:"\/p-rabbitmq\/haproxy\/backend\/retries\/amqp" value:\d+ unit:"count"/, polling_interval: 60)
      end

      it 'does not contain haproxy_z1 amqp connection time' do
        expect(@firehose).to_not have_metric('haproxy_z1', 0, /name:"\/p-rabbitmq\/haproxy\/backend\/ctime\/amqp" value:\d+ unit:"time"/, polling_interval: 60)
      end
    end
  end
end

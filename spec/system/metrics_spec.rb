require 'spec_helper'
require 'spec_matcher'
require 'date'

RSpec.describe 'metrics', :skip_metrics => true do
  let(:firehose) { Firehose.new(doppler_address: doppler_address, access_token: cf.auth_token) }

  describe 'rabbitmq haproxy metrics' do
    before(:all) do
      @ha_host = bosh_director.ips_for_job('haproxy_z1', environment.bosh_manifest.deployment_name)[0]
    end

    context 'when haproxy_z1 is running' do
      before(:all) do
        ssh_gateway.execute_on(@ha_host, '/var/vcap/bosh/bin/monit start rabbitmq-haproxy', :root => true)
      end

      it 'contains haproxy_z1 metric for rabbitmq haproxy nodes' do
        expect(firehose).to have_metric('haproxy_z1', 0, /name:"\/p-rabbitmq\/haproxy\/heartbeat" value:1 unit:"boolean"/)
      end
    end

    context 'when haproxy_z1 is not running' do
      before(:all) do
        ssh_gateway.execute_on(@ha_host, '/var/vcap/bosh/bin/monit stop rabbitmq-haproxy', :root => true)
      end

      after(:all) do
        ssh_gateway.execute_on(@ha_host, '/var/vcap/bosh/bin/monit start rabbitmq-haproxy', :root => true)
      end

      it 'contains haproxy_z1 metrics for rabbitmq haproxy nodes' do
        expect(firehose).to have_metric('haproxy_z1', 0, /name:"\/p-rabbitmq\/haproxy\/heartbeat" value:0 unit:"boolean"/)
      end
    end
  end

  describe 'rabbitmq server metrics' do
    it 'contains rmq_z1 heartbeat node metrics' do
      expect(firehose).to have_metric('rmq_z1', 0, /name:"\/p-rabbitmq\/rabbitmq\/heartbeat" value:1 unit:"boolean"/)
    end

    it 'contains rmq_z1 process count metrics' do
      expect(firehose).to have_metric('rmq_z1', 0, /name:"\/p-rabbitmq\/rabbitmq\/erlang\/erlang_processes" value:[1-9][0-9]* unit:"count"/)
    end

    it 'contains the heartbeat metrics for all RabbitMQ nodes' do
      expect(firehose).to have_metric('rmq_z1', 0, /name:"\/p-rabbitmq\/rabbitmq\/heartbeat" value:1 unit:"boolean"/)
      expect(firehose).to have_metric('rmq_z2', 0, /name:"\/p-rabbitmq\/rabbitmq\/heartbeat" value:1 unit:"boolean"/)
    end

    context 'when all RabbitMQ nodes are not running' do
      before(:all) do
        @rmq_z1_host = bosh_director.ips_for_job('rmq_z1', environment.bosh_manifest.deployment_name)[0]
        @rmq_z2_host = bosh_director.ips_for_job('rmq_z2', environment.bosh_manifest.deployment_name)[0]
        ssh_gateway.execute_on(@rmq_z1_host, '/var/vcap/bosh/bin/monit stop rabbitmq-server', :root => true)
        ssh_gateway.execute_on(@rmq_z2_host, '/var/vcap/bosh/bin/monit stop rabbitmq-server', :root => true)
      end

      after(:all) do
        ssh_gateway.execute_on(@rmq_z1_host, '/var/vcap/bosh/bin/monit start rabbitmq-server', :root => true)
        ssh_gateway.execute_on(@rmq_z2_host, '/var/vcap/bosh/bin/monit start rabbitmq-server', :root => true)
      end

      it 'contains rmq_z1 and rmq_z2 heartbeat node metrics' do
        expect(firehose).to have_metric('rmq_z1', 0, /name:"\/p-rabbitmq\/rabbitmq\/heartbeat" value:0 unit:"boolean"/)
        expect(firehose).to have_metric('rmq_z2', 0, /name:"\/p-rabbitmq\/rabbitmq\/heartbeat" value:0 unit:"boolean"/)
      end

      it 'contains rmq_z1 and rmq_z2 process count metrics' do
        expect(firehose).to have_metric('rmq_z1', 0, /name:"\/p-rabbitmq\/rabbitmq\/erlang\/erlang_processes" value:0 unit:"count"/)
        expect(firehose).to have_metric('rmq_z2', 0, /name:"\/p-rabbitmq\/rabbitmq\/erlang\/erlang_processes" value:0 unit:"count"/)
      end
    end
  end

  describe 'rabbitmq broker metrics' do
    it 'contains rmq-broker node metrics' do
      expect(firehose).to have_metric('rmq-broker', 0, /name:"\/p-rabbitmq\/service_broker\/heartbeat" value:1 unit:"boolean"/)
    end

    context 'when rmq-broker is not running' do
      before(:all) do
        @rmq_broker_host = bosh_director.ips_for_job('rmq-broker', environment.bosh_manifest.deployment_name)[0]
        ssh_gateway.execute_on(@rmq_broker_host, '/var/vcap/bosh/bin/monit stop rabbitmq-broker', :root => true)
      end

      after(:all) do
        ssh_gateway.execute_on(@rmq_broker_host, '/var/vcap/bosh/bin/monit start rabbitmq-broker', :root => true)
      end

      it 'contains rmq-broker node metrics' do
        expect(firehose).to have_metric('rmq-broker', 0, /name:"\/p-rabbitmq\/service_broker\/heartbeat" value:0 unit:"boolean"/)
      end
    end
  end
end

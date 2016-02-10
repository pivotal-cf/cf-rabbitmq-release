require 'spec_helper'

require 'json'
require 'ostruct'
require 'tempfile'
require 'nokogiri'

require 'hula'
require 'hula/bosh_manifest'
require 'prof/marketplace_service'
require 'prof/service_instance'
require 'prof/cloud_foundry'
require 'prof/test_app'
require 'rabbitmq/http/client'

require "mqtt"
require "stomp"

require File.expand_path('../../../../system_test/test_app/lib/lab_rat/aggregate_health_checker.rb', __FILE__)


describe 'Logging a Cloud Foundry service broker' do
  RMQ_BROKER_JOB = "rmq-broker"
  RMQ_BROKER_JOB_INDEX = 0

  RMQ_SERVER_Z1_JOB = "rmq_z1"
  RMQ_SERVER_Z1_JOB_INDEX = 0

  RMQ_SERVER_Z2_JOB = "rmq_z2"
  RMQ_SERVER_Z2_JOB_INDEX = 0

  let(:service_name) { environment.bosh_manifest.property('rabbitmq-broker.service.name') }
  let(:service) { Prof::MarketplaceService.new(name: service_name, plan: 'standard') }
  let(:rmq_broker_host)  { bosh_director.ips_for_job(RMQ_BROKER_JOB, environment.bosh_manifest.deployment_name)[RMQ_BROKER_JOB_INDEX] }
  let(:rmq_broker_stdout_log) { ssh_gateway.execute_on(rmq_broker_host, "cat /var/vcap/sys/log/rabbitmq-broker/startup_stdout.log") }
  let(:rmq_broker_stderr_log) { ssh_gateway.execute_on(rmq_broker_host, "cat /var/vcap/sys/log/rabbitmq-broker/startup_stderr.log") }

  before(:all) do
    register_broker
  end

  after(:all) do
    deregister_broker
  end

  describe 'provisions a service' do
    it 'and writes the operation into the stdout logs', :creates_service_key do
      cf.provision_and_create_service_key(service) do |_, _, service_key_data|
        service_instance_id = service_key_data['vhost']
        expect(rmq_broker_stdout_log).to include "Asked to provision a service: #{service_instance_id}"
      end
    end

    context 'when the nodes are down' do
      before(:all) do
        bosh_director.stop(RMQ_SERVER_Z1_JOB, RMQ_SERVER_Z1_JOB_INDEX)
        bosh_director.stop(RMQ_SERVER_Z2_JOB, RMQ_SERVER_Z2_JOB_INDEX)
      end

      after(:all) do
        bosh_director.start(RMQ_SERVER_Z1_JOB, RMQ_SERVER_Z1_JOB_INDEX)
        bosh_director.start(RMQ_SERVER_Z2_JOB, RMQ_SERVER_Z2_JOB_INDEX)
      end

      it 'writes the error in stderr log', :creates_service_key do
        expect{ cf.provision_and_create_service_key(service) }.to raise_error do |e|
          service_instance_id = get_uuid(e.message)
          expect(rmq_broker_stderr_log).to include "Failed to provision a service: #{service_instance_id}"
        end
      end
    end
  end

  describe 'deprovisions a service' do
    it 'and writes the operation into the stdout logs', :creates_service_key do
      cf.provision_and_create_service_key(service) do |service_instance, service_key, service_key_data|
        @service_instance_id = service_key_data['vhost']
      end

      expect(rmq_broker_stdout_log).to include "Asked to deprovision a service: #{@service_instance_id}"
    end

    context 'when the nodes are down' do
      after(:all) do
        bosh_director.start(RMQ_SERVER_Z1_JOB, RMQ_SERVER_Z1_JOB_INDEX)
        bosh_director.start(RMQ_SERVER_Z2_JOB, RMQ_SERVER_Z2_JOB_INDEX)
      end

      it 'writes the error into stderr log', :creates_service_key do
        expect do
          cf.provision_service(service, :allow_failure => false) do |_|
            bosh_director.stop(RMQ_SERVER_Z1_JOB, RMQ_SERVER_Z1_JOB_INDEX)
            bosh_director.stop(RMQ_SERVER_Z2_JOB, RMQ_SERVER_Z2_JOB_INDEX)
          end
        end.to raise_error do |e|
          service_instance_id = get_uuid(e.message)
          expect(rmq_broker_stderr_log).to include "Failed to deprovision a service: #{service_instance_id}"
        end
      end
    end
  end

  describe 'binds a service' do
    it 'and writes the operation into the stdout logs', :creates_service_key, :pushes_cf_app do
      cf.provision_and_create_service_key(service) do |service_instance, service_key, service_key_data|
        cf.push_app_and_bind_with_service_instance(test_app, service_instance) do |_, _|
          service_instance_id = service_key_data['vhost']
          expect(rmq_broker_stdout_log).to include "Asked to bind a service: #{service_instance_id}"
        end
      end
    end

    context 'when the nodes are down' do
      after(:all) do
        bosh_director.start(RMQ_SERVER_Z1_JOB, RMQ_SERVER_Z1_JOB_INDEX)
        bosh_director.start(RMQ_SERVER_Z2_JOB, RMQ_SERVER_Z2_JOB_INDEX)
      end

      it 'writes the error into the stderr logs', :creates_service_key do
        cf.provision_and_create_service_key(service) do |service_instance, service_key, service_key_data|
          @service_instance_id = service_key_data['vhost']

          bosh_director.stop(RMQ_SERVER_Z1_JOB, RMQ_SERVER_Z1_JOB_INDEX)
          bosh_director.stop(RMQ_SERVER_Z2_JOB, RMQ_SERVER_Z2_JOB_INDEX)

          expect { cf.push_app_and_bind_with_service_instance(test_app, service_instance) { |_, _| } }.to raise_error do |e|
            bosh_director.start(RMQ_SERVER_Z1_JOB, RMQ_SERVER_Z1_JOB_INDEX)
            bosh_director.start(RMQ_SERVER_Z2_JOB, RMQ_SERVER_Z2_JOB_INDEX)

            expect(rmq_broker_stderr_log).to include "Failed to bind a service: #{@service_instance_id}"
          end
        end
      end
    end

    describe 'unbinds a service' do
      it 'and writes the operation into the stdout logs', :creates_service_key, :pushes_cf_app do
        cf.provision_and_create_service_key(service) do |service_instance, service_key, service_key_data|
          cf.push_app_and_bind_with_service_instance(test_app, service_instance) { |_, _| }
          service_instance_id = service_key_data['vhost']
          expect(rmq_broker_stdout_log).to include "Asked to unbind a service: #{service_instance_id}"
        end
      end

      context 'when the nodes are down' do
        after(:all) do
          bosh_director.start(RMQ_SERVER_Z1_JOB, RMQ_SERVER_Z1_JOB_INDEX)
          bosh_director.start(RMQ_SERVER_Z2_JOB, RMQ_SERVER_Z2_JOB_INDEX)
        end

        it 'writes the error into tthe stderr logs', :pushes_cf_app do
          expect do
            cf.push_app_and_bind_with_service(test_app, service) do |_, _|
              bosh_director.stop(RMQ_SERVER_Z1_JOB, RMQ_SERVER_Z1_JOB_INDEX)
              bosh_director.stop(RMQ_SERVER_Z2_JOB, RMQ_SERVER_Z2_JOB_INDEX)
            end
          end.to raise_error do |e|
            service_instance_id = get_uuid(e.message)
            bosh_director.start(RMQ_SERVER_Z1_JOB, RMQ_SERVER_Z1_JOB_INDEX)
            bosh_director.start(RMQ_SERVER_Z2_JOB, RMQ_SERVER_Z2_JOB_INDEX)
            expect(rmq_broker_stderr_log).to include "Failed to unbind a service: #{service_instance_id}"
          end
        end
      end
    end
  end
end

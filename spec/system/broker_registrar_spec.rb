require 'spec_helper'

require 'hula'

RSpec.describe 'Broker Registrar', :broker, test_with_errands: true do
  before(:all) do
    deregister_broker

    @rand_str = rand(36**8).to_s(36)
    @orgs = (1..4).to_a.map{|i| "#{@rand_str}_#{i}"}
    @space = 'test'

    @orgs.each do |org|
      cf.create_and_target_org(org)
      cf.create_space(@space)
    end

    @new_org = "#{@rand_str}_new"
  end

  after(:all) do
    @orgs.each do |org|
      cf.delete_org(org)
    end

    register_broker
  end

  let(:service_name) { environment.bosh_manifest.property('rabbitmq-broker.service.name') }

  context 'when the orgs propery is not set' do
    before(:all) do
      register_broker
    end

    after(:all) do
      deregister_broker
      cf.delete_org(@new_org)
    end

    it 'enables access to the service broker for all orgs' do
      @orgs.each do |org|
        cf.target_org(org)
        cf.target_space(@space)
        expect(service_available?(service_name)).to be_truthy
      end

      cf.create_and_target_org(@new_org)
      cf.create_and_target_space(@space)
      expect(service_available?(service_name)).to be_truthy
    end
  end

  context 'when the orgs property is set' do
    before(:all) do
      @enabled_orgs = @orgs[0, 2]
      @disabled_orgs = @orgs[2, 4]

      modify_and_deploy_manifest do |manifest|
        errand = manifest.fetch('instance_groups').detect{ |j| j['name'] == 'broker-registrar' }
        errand['properties'] ||= {}
        errand['properties']['broker-registrar'] = { 'orgs' => @enabled_orgs }
      end

      register_broker
    end

    after(:all) do
      deregister_broker
      bosh_director.deploy(environment.bosh_manifest.path)
      cf.delete_org(@new_org)
    end

    it 'enables access to the service broker for the specified orgs only' do
      @enabled_orgs.each do |org|
        cf.target_org(org)
        cf.target_space(@space)
        expect(service_available?(service_name)).to be_truthy
      end

      @disabled_orgs.each do |org|
        cf.target_org(org)
        cf.target_space(@space)
        expect(service_available?(service_name)).to be_falsey
      end

      cf.create_and_target_org(@new_org)
      cf.create_and_target_space(@space)
      expect(service_available?(service_name)).to be_falsey
    end
  end
end

def service_available?(name)
  !! (cf.marketplace).match(/^#{name}\s+/)
end


require 'prof/external_spec/spec_helper'
require 'prof/environment/cloud_foundry'
require 'prof/environment_manager'
require 'prof/ssh_gateway'

require 'pry'

RSpec.configure do |config|

  config.formatter = :documentation
  config.filter_run :focus
  config.run_all_when_everything_filtered = true

  config.around do |example|
    if example.metadata[:pushes_cf_app] || example.metadata[:creates_service_key]

      environment_manager.isolate_cloud_foundry do
        example.run
      end
    else
      example.run
    end
  end
end

def environment
  @environment ||= begin
    options = {
      bosh_manifest_path: ENV.fetch('BOSH_MANIFEST') { File.expand_path('../../manifests/cf-rabbitmq-lite.yml', __FILE__) },
      bosh_service_broker_job_name: 'cf-rabbitmq-broker'
    }

    options[:cloud_foundry_domain]   = ENV['CF_DOMAIN']   ? ENV['CF_DOMAIN']   : 'bosh-lite.com'
    options[:cloud_foundry_username] = ENV['CF_USERNAME'] ? ENV['CF_USERNAME'] : 'admin'
    options[:cloud_foundry_password] = ENV['CF_PASSWORD'] ? ENV['CF_PASSWORD'] : 'admin'
    options[:cloud_foundry_api_url]  = ENV['CF_API']      ? ENV['CF_API']      : 'api.bosh-lite.com'

    options[:bosh_target]          = ENV['BOSH_TARGET']   if ENV.key?('BOSH_TARGET')
    options[:bosh_username]        = ENV['BOSH_USERNAME'] if ENV.key?('BOSH_USERNAME')
    options[:bosh_password]        = ENV['BOSH_PASSWORD'] if ENV.key?('BOSH_PASSWORD')
    options[:ssh_gateway_host]     = ENV['BOSH_TARGET']   if ENV.key?('BOSH_TARGET')

    options[:ssh_gateway_username] = 'vcap'               if ENV.key?('BOSH_TARGET')
    options[:ssh_gateway_password] = 'c1oudc0w'           if ENV.key?('BOSH_TARGET')

    Prof::Environment::CloudFoundry.new(options)
  end
end

def bosh_director
  @bosh_director ||= environment.bosh_director
end

def environment_manager
  cf_environment = OpenStruct.new(:cloud_foundry => cf, :bosh_director => bosh_director)
  Prof::EnvironmentManager.new(cf_environment)
end

def cf
  @cf ||= environment.cloud_foundry
end

def ssh_gateway
  @ssh_gateway ||= environment.ssh_gateway
end

def test_app
  @test_app ||= Prof::TestApp.new(path: File.expand_path('../../system_test/test_app', __FILE__))
end

def modify_and_deploy_manifest
  manifest = YAML.load_file(environment.bosh_manifest.path)

  yield manifest

  Tempfile.open('manifest.yml') do |manifest_file|
    manifest_file.write(manifest.to_yaml)
    bosh_director.deploy(manifest_file.path)
  end
end

def register_broker
    bosh_director.run_errand('broker-registrar') unless ENV.has_key?('SKIP_ERRANDS')
end

def deregister_broker
    bosh_director.run_errand('broker-deregistrar') unless ENV.has_key?('SKIP_ERRANDS')
end

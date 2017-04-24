require 'prof/external_spec/spec_helper'
require 'prof/environment/cloud_foundry'
require 'prof/environment_manager'
require 'prof/ssh_gateway'
require 'yaml'
require 'pry'
require 'rspec/retry'

Dir[File.expand_path('support/**/*.rb', __dir__)].each do |file|
  require file
end

def environment
  @environment ||= begin
                     options = {
                       bosh_manifest_path: ENV.fetch('BOSH_MANIFEST') { File.expand_path('../../manifests/cf-rabbitmq.yml', __FILE__) },
                       bosh_service_broker_job_name: 'cf-rabbitmq-broker'
                     }

                     options[:cloud_foundry_domain]   = ENV.fetch('CF_DOMAIN', 'bosh-lite.com')
                     options[:cloud_foundry_username] = ENV.fetch('CF_USERNAME', 'admin')
                     options[:cloud_foundry_password] = ENV.fetch('CF_PASSWORD', 'admin')
                     options[:cloud_foundry_api_url]  = ENV.fetch('CF_API', 'api.bosh-lite.com')

                     options[:bosh_target]          = ENV['BOSH_TARGET']
                     options[:bosh_username]        = ENV['BOSH_USERNAME']
                     options[:bosh_password]        = ENV['BOSH_PASSWORD']
                     options[:ssh_gateway_host]     = URI.parse(ENV['BOSH_TARGET']).host if ENV.key?('BOSH_TARGET')

                     options[:ssh_gateway_username] = ENV.fetch('BOSH_SSH_USERNAME', 'vcap') if ENV.key?('BOSH_TARGET')

                     options.keep_if do |key, value|
                       not value.nil?
                     end

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

  deploy_manifest(manifest)
end

def deploy_manifest(manifest)
  Tempfile.open('manifest.yml') do |manifest_file|
    manifest_file.write(manifest.to_yaml)
    manifest_file.flush
    bosh_director.deploy(manifest_file.path)
  end
end

def doppler_address
  @doppler_address ||= cf.info["doppler_logging_endpoint"]
end

def register_broker
  bosh_director.run_errand('broker-registrar') unless ENV.has_key?('SKIP_ERRANDS')
end

def deregister_broker
  bosh_director.run_errand('broker-deregistrar') unless ENV.has_key?('SKIP_ERRANDS')
end

def get_uuid(content)
  uuid_regex = /(\w{8}(-\w{4}){3}-\w{12}?)/
  uuid_regex.match(content)[0]
end

def get_service_instance_uuid(content)
  uuid_regex = /service_instances\/(\w{8}(-\w{4}){3}-\w{12}?)\/service_bindings/
  uuid_regex.match(content)[1]
end

def stop_connections_to_job(options = {})
  job_hosts = options.fetch(:hosts)
  protocol = options.fetch(:protocol, 'tcp')
  port = options.fetch(:port, 80)

  job_hosts.each do |job_host|
    ssh_gateway.execute_on(job_host, "iptables -w -A INPUT -p #{protocol} --destination-port #{port} -j DROP", :root => true)
  end

  yield
ensure
  job_hosts.each do |job_host|
    ssh_gateway.execute_on(job_host, "iptables -w -D INPUT -p #{protocol} --destination-port #{port} -j DROP", :root => true)
  end
end

def wait_for(job:, status:)
  ssh_gateway.execute_on(@haproxy_z1_host, "while ! ( monit summary | grep #{job} | grep \'#{status}\' > /dev/null); do true; done", :root => true)
end

module ExcludeHelper
  def self.manifest
    @bosh_manifest ||= YAML.load(File.read(ENV['BOSH_MANIFEST']))
  end

  def self.metrics_available?
    return unless ENV['BOSH_MANIFEST']
    0 != manifest.fetch('releases').select{|i| i["name"] == "service-metrics" }.length
  end

  def self.warnings
    message = "\n"
    if !metrics_available?
      message += "WARNING: Skipping metrics tests, metrics are not available in this manifest\n"
    end

    message + "\n"
  end
end

puts ExcludeHelper::warnings

RSpec.configure do |config|
  config.include Matchers
  config.include TemplateHelpers, template: true

  Matchers::prints_logs_on_failure = true

  config.filter_run :focus
  config.run_all_when_everything_filtered = true
  config.filter_run_excluding :metrics => !ExcludeHelper::metrics_available?
  config.filter_run_excluding :broker => ENV.has_key?('SKIP_BROKER')
  config.filter_run_excluding :test_with_errands => ENV.has_key?('SKIP_ERRANDS')
  config.filter_run_excluding :run_compliance_tests => (!ENV.has_key?('RUN_COMPLIANCE') && /darwin|mac os/ === RbConfig::CONFIG['host_os'] )

  config.around do |example|
    if example.metadata[:pushes_cf_app] || example.metadata[:creates_service_key]

      environment_manager.isolate_cloud_foundry do
        example.run
      end
    else
      example.run
    end
  end

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.disable_monkey_patching!

  # show retry status in spec process
  config.verbose_retry = true
  # show exception that triggers a retry if verbose_retry is set to true
  config.display_try_failure_messages = true

  config.around :each, :retryable do |ex|
    ex.run_with_retry retry: 60, retry_wait: 10
  end

  Kernel.srand config.seed
end

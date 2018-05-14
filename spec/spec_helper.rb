require 'yaml'
require 'pry'
require 'json'
require 'rspec/retry'
require 'shellwords'
require 'open3'

Dir[File.expand_path('support/**/*.rb', __dir__)].each do |file|
  require file
end

BOSH_CLI = ENV.fetch('BOSH_CLI', 'bosh')

def execute(command)
  output, = Open3.capture2(command)
  output
end

class Bosh2
  def initialize(bosh_cli = 'bosh')
    @bosh_cli = "#{bosh_cli} -n"

    version = execute("#{@bosh_cli} --version")
    raise 'BOSH CLI >= v2 required' if version.start_with?('version 1.')
  end

  def ssh(instance, command)
    command_escaped = Shellwords.escape(command)
    output = execute("#{@bosh_cli} ssh #{instance} -r --json -c #{command_escaped}")
    JSON.parse(output)
  end

  def indexed_instance(instance, index)
    output = execute("#{@bosh_cli} instances | grep #{instance} | cut -f1")
    output.split(' ')[index]
  end

  def deploy(manifest)
    Tempfile.open('manifest.yml') do |manifest_file|
      manifest_file.write(manifest.to_yaml)
      manifest_file.flush
      output = ''
      exit_code = ::Open3.popen3("#{@bosh_cli} deploy #{manifest_file.path}") do |_stdin, stdout, _stderr, wait_thr|
        output << stdout.read
        wait_thr.value
      end
      abort "Deployment failed\n#{output}" unless exit_code == 0
    end
  end

  def redeploy
    deployed_manifest = manifest
    yield deployed_manifest
    deploy deployed_manifest
  end

  def manifest
    manifest = execute("#{@bosh_cli} manifest")
    YAML.safe_load(manifest)
  end

  def start(instance)
    execute("#{@bosh_cli} start #{instance}")
  end

  def stop(instance, should_skip_drain = false)
    skip_drain = '--skip-drain' if should_skip_drain
    execute("#{@bosh_cli} stop #{skip_drain} #{instance}")
  end
end

def bosh
  @bosh ||= Bosh2.new(BOSH_CLI)
end

def test_manifest
  YAML.load_file(ENV.fetch('BOSH_MANIFEST'))
end

def get(endpoint, username, password)
  response = HTTParty.get(endpoint, basic_auth: { username: username, password: password })
  JSON.parse(response.body)
end

def rabbitmq_api_url
  manifest = bosh.manifest
  rabbitmq_api = get_properties(manifest, 'haproxy', 'route_registrar')['route_registrar']['routes'].first['uris'].first
  "http://#{rabbitmq_api}/api"
end

def get_properties(manifest, instance_group_name, job_name)
  instance_group = manifest['instance_groups'].select { |instance_group| instance_group['name'] == instance_group_name }.first
  raise "No instance group named #{instance_group_name} found in manifest:\n#{manifest}" if instance_group.nil?

  job = instance_group['jobs'].select { |job| job['name'] == job_name }.first
  raise "No job named #{job_name} found in instance group named #{instance_group_name} in manifest:\n#{manifest}" if job.nil?

  raise "No properties found for job #{job_name} in instance group #{instance_group_name} in manifest\n#{manifest}" unless job.key?('properties')
  job['properties']
end

RSpec.configure do |config|
  config.include Matchers
  config.include TemplateHelpers, template: true

  Matchers.prints_logs_on_failure = true

  config.filter_run :focus
  config.run_all_when_everything_filtered = true
  config.filter_run_excluding run_compliance_tests: (!ENV.key?('RUN_COMPLIANCE') && RbConfig::CONFIG['host_os'] === /darwin|mac os/)

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

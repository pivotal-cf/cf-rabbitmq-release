require 'yaml'
require 'pry'
require 'json'
require 'rspec/retry'
require 'shellwords'

Dir[File.expand_path('support/**/*.rb', __dir__)].each do |file|
  require file
end

class Bosh2
  def ssh(instance, command)
    command_escaped = Shellwords.escape(command)
    output = `boshgo -n ssh #{instance} -r --json -c #{command_escaped}`
    JSON.parse(output)
  end

  def deploy(manifest)
    Tempfile.open('manifest.yml') do |manifest_file|
      manifest_file.write(manifest.to_yaml)
      manifest_file.flush
      `boshgo -n deploy #{manifest_file.path}`
    end
  end

  def redeploy
    deployed_manifest = manifest
    yield deployed_manifest
    deploy deployed_manifest
  end

  def manifest
    manifest = `boshgo -n manifest`
    YAML.load(manifest)
  end

  def start(instance)
    `boshgo -n start #{instance}`
  end

  def stop(instance)
    `boshgo -n stop #{instance}`
  end
end

def bosh
  @bosh ||= Bosh2.new
end

def test_manifest
  YAML.load_file(ENV.fetch('BOSH_MANIFEST'))
end

RSpec.configure do |config|
  config.include Matchers
  config.include TemplateHelpers, template: true

  Matchers::prints_logs_on_failure = true

  config.filter_run :focus
  config.run_all_when_everything_filtered = true
  config.filter_run_excluding :run_compliance_tests => (!ENV.has_key?('RUN_COMPLIANCE') && /darwin|mac os/ === RbConfig::CONFIG['host_os'] )

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

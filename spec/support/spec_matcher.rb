require 'rspec/expectations'
require 'yaml'

module Matchers
  class Firehose
    def initialize(doppler_address:, access_token:)
      @doppler_address = doppler_address
      @access_token = access_token
    end

    def read_log
      file = Tempfile.new('smetrics')
      pid = spawn(
        {
          'DOPPLER_ADDR' => @doppler_address,
          'CF_ACCESS_TOKEN' => @access_token,
        },
        'firehose',
        [:out, :err] => [file.path, 'w']
      )

      yield(file)

      Process.kill("INT", pid)
      file.close
      file.unlink
    end

    def self.get_deployment_name
      manifest_path = ENV.fetch('BOSH_MANIFEST') { File.expand_path('../../manifests/cf-rabbitmq-lite.yml', __FILE__) }
      manifest = YAML.load(File.open(manifest_path).read)
      if manifest['properties']['metron_agent'].nil? or manifest['properties']['metron_agent']['deployment'].nil?
        "cf-rabbitmq"
      else
        manifest['properties']['metron_agent']['deployment']
      end
    end
  end

  RSpec::Matchers.define :have_metric do |job_name, job_index, metric_regex_pattern|
    match do |firehose|
      metric_exist = false
      @actual = []

      firehose.read_log do |file|
        61.times do
          lines = file.readlines
          @actual << lines

          metric_exist = lines.grep(metric_regex_pattern).any? do |metric|
            matched = metric.include? 'origin:"p-rabbitmq"'
            matched &= metric.include? "deployment:\"#{firehose.class.get_deployment_name}\""
            matched &= metric.include? 'eventType:ValueMetric'
            matched &= metric =~ /job:\".*#{job_name}.*\"/
              matched &= metric.include? "index:\"#{job_index}\""

            matched &= metric =~ /timestamp:\d/
            matched &= metric =~ /ip:"\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}"/
          end

          break if metric_exist
          sleep 1
        end
      end

      metric_exist
    end

    failure_message do |actual|
      contents = actual.join

      "expected #{contents} to contains metric '#{metric_regex_pattern}' for job '#{job_name}' with index '#{job_index}'"
    end
  end
end

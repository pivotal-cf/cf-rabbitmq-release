require 'rspec/expectations'
require 'yaml'

module Matchers
  class Firehose
    def initialize(doppler_address:, access_token:)
      @doppler_address = doppler_address
      @access_token = access_token

      @file = Tempfile.new('smetrics')
      @pid = spawn(
        {
          'DOPPLER_ADDR' => @doppler_address,
          'CF_ACCESS_TOKEN' => @access_token,
        },
        'firehose',
        [:out, :err] => [@file.path, 'w']
      )
    end

    def count
      @count ||= 300
    end

    def count=(value)
      @count = value
    end

    def close
      Process.kill("INT", @pid)
      @file.close
      @file.unlink
    end

    def read_log
      yield(@file)
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

      firehose.read_log do |file|
        while firehose.count > 1 do
          firehose.count = firehose.count - 1

          file.rewind
          lines = file.readlines

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
      "expected to contains metric '#{metric_regex_pattern}' for job '#{job_name}' with index '#{job_index}'"
    end
  end
end

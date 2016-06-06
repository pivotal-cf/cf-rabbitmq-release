require 'rspec/expectations'
require 'yaml'

module Matchers
  class << self
    attr_accessor :prints_logs_on_failure
  end

  self.prints_logs_on_failure = false

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

    def close
      Process.kill("INT", @pid)

      @file.close
      @file.unlink
    end

    def read_log
      read_file = File.open(@file.path)
      yield(read_file)
    ensure
      read_file.close
    end
  end

  RSpec::Matchers.define :have_metric do |job_name, job_index, metric_regex_pattern, polling_interval: 600|
    match do |firehose|
      metric_exist = false

      firehose.read_log do |file|
        polling_interval.times do
          lines = file.readlines
          @actual = lines

          metric_exist = lines.grep(metric_regex_pattern).any? do |metric|
            matched = metric.include? 'origin:"p-rabbitmq"'
            matched &= metric.include? "deployment:\"#{deployment_name}\""
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
      msg = "expected to contains metric '#{metric_regex_pattern}' for job '#{job_name}' with index '#{job_index}'"

      if Matchers::prints_logs_on_failure
        msg << actual.join('\n')
      end

      msg
    end
  end


  def deployment_name
    manifest_path = ENV.fetch('BOSH_MANIFEST') { File.expand_path('../../manifests/cf-rabbitmq-lite.yml', __FILE__) }
    manifest = YAML.load(File.open(manifest_path).read)
    if manifest["name"].nil? or manifest["name"].empty?
      "cf-rabbitmq"
    else
      manifest['name']
    end
  end
end

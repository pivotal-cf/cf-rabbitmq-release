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
      @lines = []
    end

    def each_line(timeout)
      killtime = Time.now + timeout
      envs = {'DOPPLER_ADDR' => @doppler_address, 'CF_ACCESS_TOKEN' => @access_token}

      PTY.spawn(envs, 'firehose') do |stdout, stdin, pid|
        @stdout = stdout
        @pid = pid
        num_read_lines = 0

        stdout.each_line do |file_line|
          @lines << file_line
          @lines.drop(num_read_lines).each do |line|
            num_read_lines += 1
            if Time.now > killtime
              stop
            end
            yield line
          end
        end
      end

    rescue
      # do not throw this exception in case of kill
    end

    def stop
      Process.kill("KILL", @pid)
    rescue
      # do not throw this exception in case of kill
    end

  end

  RSpec::Matchers.define :have_metrics do |job_name, job_index, regex_patterns, polling_interval: 600|
    match do |firehose|
      @actual = []

      not_matched_metrics = match_metrics(firehose, polling_interval, job_name, job_index, regex_patterns) do |line|
        @actual << line
      end

      not_matched_metrics.empty?
    end

    failure_message do |actual|
      log = File.open("metrics_#{Time.now.to_i}.log", 'w')
      log.write(actual.join('\n'))
      log.close
      "expected to contains metric '#{regex_patterns}' for job '#{job_name}' with index '#{job_index}' but has log #{log.path}"
    end
  end

  RSpec::Matchers.define :have_not_metrics do |job_name, job_index, regex_patterns, polling_interval: 600|
    match do |firehose|
      @actual = []

      not_matched_metrics = match_metrics(firehose, polling_interval, job_name, job_index, regex_patterns) do |line|
        @actual << line
      end

      regex_patterns.length == not_matched_metrics.length
    end

    failure_message do |actual|
      log = File.open("metrics_#{Time.now.to_i}.log", 'w')
      log.write(actual.join('\n'))
      log.close
      "expected to contains metric '#{regex_patterns}' for job '#{job_name}' with index '#{job_index}' but has log #{log.path}"
    end
  end

  def match_metrics(firehose, polling_interval, job_name, job_index, regex_patterns)
    firehose.each_line(polling_interval) do |line|
      yield line

      regex_patterns = regex_patterns.delete_if do |metric_regex_pattern|
        metric_exist = (line =~ metric_regex_pattern) != nil
        metric_exist &= line.include? 'origin:"p-rabbitmq"'
        metric_exist &= line.include? "deployment:\"#{deployment_name}\""
        metric_exist &= line.include? 'eventType:ValueMetric'
        metric_exist &= line =~ /job:\".*#{job_name}.*\"/
        metric_exist &= line.include? "index:\"#{job_index}\""

        metric_exist &= line =~ /timestamp:\d/
        metric_exist &= line =~ /ip:"\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}"/

        metric_exist
      end

      if regex_patterns.empty?
        firehose.stop
        break
      end
    end

    regex_patterns
  end

  def deployment_name
    manifest_path = ENV.fetch('BOSH_MANIFEST') { File.expand_path('../../manifests/cf-rabbitmq.yml', __FILE__) }
    manifest = YAML.load(File.open(manifest_path).read)
    if manifest["name"].nil? or manifest["name"].empty?
      "cf-rabbitmq"
    else
      manifest['name']
    end
  end
end

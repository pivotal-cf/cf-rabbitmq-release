require 'spec_helper'
require 'httparty'
require 'yaml'
require 'json'

RSpec.describe 'RabbitMQ cluster status during upgrade' do

  let(:manifest) { YAML.load_file(ENV['BOSH_MANIFEST']) }
  let(:username) { manifest['properties']['rabbitmq-server']['administrators']['management']['username'] }
  let(:password) { manifest['properties']['rabbitmq-server']['administrators']['management']['password'] }
  let(:hosts) do
    jobs = manifest['jobs'].select {|job| job['template'] == 'rabbitmq-server' }
    jobs.flat_map do |job|
      job['networks'].flat_map { |network| network['static_ips'] }
    end
  end
  let(:haproxy_host) do
    haproxy_job = manifest['jobs'].detect { |job| job['template'] == 'rabbitmq-haproxy' }
    haproxy_job['networks'].first['static_ips'].first
  end
  let(:sleep_interval) { 10 }
  let(:upgraded_rabbitmq_version) do
    spec = YAML.load_file(File.join(__dir__, '../..', 'packages/rabbitmq-server/spec'))
    server_package = spec['files'].detect { |spec_file| spec_file.include?('generic-unix') }
    server_package[/unix\-(.*)\.tar/, 1]
  end

  it 'should have all running RabbitMQ nodes on the same version' do
    log("Waiting for RabbitMQ cluster to be running on #{upgraded_rabbitmq_version}")
    while true do
      log("Upgrade is in progress - testing versions of RabbitMQ")

      versions = hosts.map do |ip|
        response = ssh_gateway.execute_on(haproxy_host, "curl -u #{username}:#{password} http://#{ip}:15672/api/overview -s")

        if valid_json?(response)
          overview = JSON.parse(response)
          overview['rabbitmq_version']
        end
      end

      log("Comparing running versions found: #{versions}")

      break if versions.all? {|version| version == upgraded_rabbitmq_version}

      # Makes sure we don't run nodes in different versions
      # Example inputs for versions:
      # ["3.4.3.1", "3.4.3.1"]
      # [nil, "3.4.3.1"]
      # [nil, nil]
      # ["3.5.6", nil]
      # ["3.5.6", "3.5.6"]
      # [nil, "a", "a", "b"] => Failing example
      expect(versions.uniq.compact.count).to be <= 1

      log("Sleeping #{sleep_interval} seconds")
      sleep sleep_interval
    end
  end

  def log(msg)
    puts "#{msg}"
  end

  def valid_json?(json)
    begin
      JSON.parse(json)
      return true
    rescue JSON::ParserError, TypeError
      return false
    end
  end
end

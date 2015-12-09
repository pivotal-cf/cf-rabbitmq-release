require 'spec_helper'
require 'httparty'
require 'yaml'
require 'json'

describe 'RabbitMQ cluster status during upgrade' do

  let(:manifest) { YAML.load_file(ENV['BOSH_MANIFEST']) }
  let(:username) { manifest['properties']['rabbitmq-server']['administrators']['management']['username'] }
  let(:password) { manifest['properties']['rabbitmq-server']['administrators']['management']['password'] }
  let(:hosts) do
    jobs = manifest['jobs'].select {|job| job['template'] == 'rabbitmq-server' }
    jobs.flat_map do |job|
      job['networks'].flat_map { |network| network['static_ips'] }
    end
  end
  let(:broker_host) do
    broker_job = manifest['jobs'].detect { |job| job['template'] == 'rabbitmq-broker' }
    broker_job['networks'].first['static_ips'].first
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
        response = ssh_gateway.execute_on(broker_host, "curl -u #{username}:#{password} http://#{ip}:15672/api/overview -s")

        if valid_json?(response)
          overview = JSON.parse(response)
          overview['rabbitmq_version']
        end
      end

      log("Comparing running versions found: #{versions}")
      # TODO: Sometimes we can have an empty array
      break if versions.all? {|version| version == upgraded_rabbitmq_version}
      expect(versions.all? {|version| version.nil? || version == versions[-1]}).to be_truthy

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
    rescue Exception => e
      return false
    end
  end
end

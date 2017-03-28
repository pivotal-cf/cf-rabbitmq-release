require 'spec_helper'
require 'httparty'
require 'yaml'
require 'json'
require 'timeout'

RSpec.describe 'RabbitMQ cluster status during upgrade' do

  let(:manifest) { YAML.load_file(ENV['BOSH_MANIFEST']) }
  let(:username) { manifest['properties']['rabbitmq-server']['administrators']['management']['username'] }
  let(:password) { manifest['properties']['rabbitmq-server']['administrators']['management']['password'] }
  let(:hosts) { hosts_with_template('rabbitmq-server') }
  let(:haproxy_host) { hosts_with_template('rabbitmq-haproxy').first }

  let(:sleep_interval) { 10 }
  let(:upgraded_rabbitmq_version) do
    spec = YAML.load_file(File.join(__dir__, '../..', 'packages/rabbitmq-server/spec'))
    server_package = spec['files'].detect { |spec_file| spec_file.include?('generic-unix') }
    server_package[/unix\-(.*)\.tar/, 1]
  end

  before {skip("in bosh v2 we do not use static_ips anymore. Shall we refactor or remove this test?")}

  it 'should have all running RabbitMQ nodes on the same version' do
    log("Waiting for RabbitMQ cluster to be running on #{upgraded_rabbitmq_version}")
    expect(hosts).not_to be_empty, 'No rabbitmq-server hosts have found in manifests'
    Timeout.timeout(60 * 60 * 2) do
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

        break if versions.all? {|version| version == upgraded_rabbitmq_version} && versions.any?

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

  def hosts_with_template(template_name)
    jobs = manifest['jobs'].select do |job|
      job['template'] == template_name ||
        ( job['templates'] &&
         job['templates'].any? {|template| template['name'] == template_name })
    end

    jobs.flat_map do |job|
      job['networks'].flat_map { |network| network['static_ips'] }
    end
  end
end

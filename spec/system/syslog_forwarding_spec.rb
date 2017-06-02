require 'spec_helper'
require 'ostruct'
require 'papertrail'
require 'httparty'
require 'uri'

def get_instances(bosh_director_url, bosh_director_username, bosh_director_password, deployment_name)
  bosh_director_uri = URI(bosh_director_url)

  JSON.parse(
    HTTParty.get(
      "#{bosh_director_uri.scheme}://#{bosh_director_uri.host}:#{bosh_director_uri.port}/deployments/#{deployment_name}/instances",
      basic_auth: {username: bosh_director_username, password: bosh_director_password},
      verify: false
    )
  ).map { |instance| OpenStruct.new(instance) }
end

DEPLOYMENT_NAME = ENV.fetch("DEPLOYMENT_NAME", "cf-rabbitmq")
BOSH_TARGET = ENV.fetch("BOSH_TARGET", "https://192.168.50.4:25555")
BOSH_USERNAME = ENV.fetch("BOSH_USERNAME", "admin")
BOSH_PASSWORD = ENV.fetch("BOSH_PASSWORD", "admin")
DEPLOYMENT_INSTANCES = get_instances(BOSH_TARGET, BOSH_USERNAME, BOSH_PASSWORD, DEPLOYMENT_NAME)

def host_search_string(host)
  "[job=#{host.job} index=#{host.index} id=#{host.id}]"
end

def one_hour_ago
  Time.now - (60 * 60)
end

RSpec.describe "Syslog forwarding", :skip_syslog do
  let(:remote_log_destination) { Papertrail::Connection.new(token: ENV.fetch("PAPERTRAIL_TOKEN")) }
  let(:papertrail_group_id) { ENV.fetch("PAPERTRAIL_GROUP_ID") }

  def has_event_for?(log_entry)
    events = []
    options = { :group_id => papertrail_group_id, :min_time => one_hour_ago }
    remote_log_destination.each_event(log_entry, options) do |event|
      events << event
    end
    events.any?
  end

  describe "rmq_server hosts" do
    rmq_server_hosts = DEPLOYMENT_INSTANCES.select { |i| i.job == "rmq" }

    rmq_server_hosts.each do |rmq_server_host|
      job_host_log_entry = host_search_string(rmq_server_host)
      it "forwards rmq_server hosts logs (#{job_host_log_entry})" do
        expect(has_event_for?(job_host_log_entry)).to be_truthy
      end
    end
  end

  describe "rmq_haproxy host" do
    rmq_haproxy_hosts = DEPLOYMENT_INSTANCES.select { |i| i.job == "haproxy" }

    rmq_haproxy_hosts.each do |rmq_haproxy_host|
      job_host_log_entry = host_search_string(rmq_haproxy_host)
      it "forwards rmq_haproxy hosts logs (#{job_host_log_entry})" do
        expect(has_event_for?(job_host_log_entry)).to be_truthy
      end
    end
  end

  describe "rmq_broker host" do
    rmq_broker_hosts = DEPLOYMENT_INSTANCES.select { |i| i.job == "rmq-broker" }

    rmq_broker_hosts.each do |rmq_broker_host|
      job_host_log_entry = host_search_string(rmq_broker_host)
      it "forwards rmq_broker hosts logs (#{job_host_log_entry})" do
        expect(has_event_for?(job_host_log_entry)).to be_truthy
      end
    end
  end
end

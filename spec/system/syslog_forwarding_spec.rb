require 'spec_helper'
require 'ostruct'
require 'papertrail'
require 'httparty'

REMOTE_LOG_DESTINATION = Papertrail::Connection.new(token: ENV.fetch("PAPERTRAIL_TOKEN"))
PAPERTRAIL_GROUP_ID = ENV.fetch("PAPERTRAIL_GROUP_ID")

DEPLOYMENT_NAME = ENV.fetch("DEPLOYMENT_NAME")
BOSH_DIRECTOR_URL = ENV.fetch("BOSH_DIRECTOR_URL")
DEPLOYMENT_INSTANCES = JSON.parse(
  HTTParty.get(
    "#{BOSH_DIRECTOR_URL}/deployments/#{DEPLOYMENT_NAME}/instances",
    verify: false
  )
).map { |i| OpenStruct.new(i) }

def host_search_string(host)
  "[job=#{host.job} index=#{host.index} id=#{host.id}]"
end

def one_day_ago
  Time.now - (24 * 60 * 60)
end

RSpec.describe "Syslog forwarding" do
  def search_for_events(search_string)
    options = { :group_id => PAPERTRAIL_GROUP_ID, :min_time => one_day_ago }
    events = []
    REMOTE_LOG_DESTINATION.each_event(search_string, options) do |event|
      events.push(event)
    end
    events
  end

  describe "rmq_server hosts" do
    rmq_server_hosts = DEPLOYMENT_INSTANCES.select { |i| i.job == "rmq" }

    rmq_server_hosts.each do |rmq_server_host|
      search_string = host_search_string(rmq_server_host)
      it "forwards rmq_server hosts logs (#{search_string})" do
        expect(search_for_events(search_string).size).to be > 0
      end
    end
  end

  describe "rmq_broker host" do
    rmq_broker_hosts = DEPLOYMENT_INSTANCES.select { |i| i.job == "rmq-broker" }

    rmq_broker_hosts.each do |rmq_broker_host|
      search_string = host_search_string(rmq_broker_host)
      it "forwards rmq_broker hosts logs (#{search_string})" do
        expect(search_for_events(search_string).size).to be > 0
      end
    end
  end

  describe "rmq_haproxy host" do
    rmq_haproxy_hosts = DEPLOYMENT_INSTANCES.select { |i| i.job == "haproxy" }

    rmq_haproxy_hosts.each do |rmq_haproxy_host|
      search_string = host_search_string(rmq_haproxy_host)
      it "forwards rmq_haproxy hosts logs (#{search_string})" do
        expect(search_for_events(search_string).size).to be > 0
      end
    end
  end
end

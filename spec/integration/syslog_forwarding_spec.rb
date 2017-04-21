require 'spec_helper'
require 'ostruct'
require 'papertrail'
require 'httparty'
require 'uri'

REMOTE_LOG_DESTINATION = Papertrail::Connection.new(token: ENV.fetch("PAPERTRAIL_TOKEN"))
PAPERTRAIL_GROUP_ID = ENV.fetch("PAPERTRAIL_GROUP_ID")

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

DEPLOYMENT_NAME = ENV.fetch("DEPLOYMENT_NAME")
BOSH_TARGET = ENV.fetch("BOSH_TARGET")
BOSH_USERNAME = ENV.fetch("BOSH_USERNAME")
BOSH_PASSWORD = ENV.fetch("BOSH_PASSWORD")
DEPLOYMENT_INSTANCES = get_instances(BOSH_TARGET, BOSH_USERNAME, BOSH_PASSWORD, DEPLOYMENT_NAME)

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

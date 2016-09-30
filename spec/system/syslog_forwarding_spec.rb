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

RSpec.describe "Syslog forwarding" do
  def logs_for_host(host)

    REMOTE_LOG_DESTINATION.query(
      "#{DEPLOYMENT_NAME}/#{host.job}/#{host.id}", group_id: PAPERTRAIL_GROUP_ID
    ).search.events
  end

  describe "rmq_server hosts" do
    let(:rmq_server_hosts) { DEPLOYMENT_INSTANCES.select { |i| i.job == "rmq" } }

    it "forwards rmq_server hosts logs" do
      rmq_server_hosts.each do |rmq_server_host|
        expect(logs_for_host(rmq_server_host).size).to be > 0
      end
    end
  end

  describe "rmq_broker host" do
    let(:rmq_broker_hosts) { DEPLOYMENT_INSTANCES.select { |i| i.job == "rmq-broker" } }

    it "forwards rmq_broker hosts logs" do
      rmq_broker_hosts.each do |rmq_broker_host|
        expect(logs_for_host(rmq_broker_host).size).to be > 0
      end
    end
  end

  describe "rmq_haproxy host" do
    let(:rmq_haproxy_hosts) { DEPLOYMENT_INSTANCES.select { |i| i.job == "haproxy" } }

    it "forwards rmq_haproxy hosts logs" do
      rmq_haproxy_hosts.each do |rmq_haproxy_host|
        expect(logs_for_host(rmq_haproxy_host).size).to be > 0
      end
    end
  end
end

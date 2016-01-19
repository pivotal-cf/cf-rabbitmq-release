require 'spec_helper'

require 'json'
require 'ostruct'
require 'tempfile'

require 'hula'
require 'hula/bosh_manifest'

describe "RabbitMQ server configuration" do

  let(:rmq_host) { bosh_director.ips_for_job("rmq_z1", environment.bosh_manifest.deployment_name)[0] }
  let(:rmq_admin_broker_username) { environment.bosh_manifest.property('rabbitmq-server.administrators.broker.username') }
  let(:rmq_admin_broker_password) { environment.bosh_manifest.property('rabbitmq-server.administrators.broker.password') }

  it "should have a file descriptor limit set by default in BOSH spec" do
    output = ssh_gateway.execute_on(rmq_host, "curl -u #{rmq_admin_broker_username}:#{rmq_admin_broker_password} http://#{rmq_host}:15672/api/nodes -s")
    nodes = JSON.parse(output)
    nodes.each do |node|
      expect(node["fd_total"]).to eq 300000
    end
  end

  context "when the manifest specifies a different file descriptor limit" do
    before :context do
      modify_and_deploy_manifest do |manifest|
        manifest["properties"]["rabbitmq-server"]["fd_limit"] = 350000
      end
    end

    after :context do
      modify_and_deploy_manifest do |manifest|
        manifest["properties"]["rabbitmq-server"].delete("fd_limit")
      end
    end

    it "should have a file descriptor limit reflecting that" do
      output = ssh_gateway.execute_on(rmq_host, "curl -u #{rmq_admin_broker_username}:#{rmq_admin_broker_password} http://#{rmq_host}:15672/api/nodes -s")
      nodes = JSON.parse(output)
      nodes.each do |node|
        expect(node["fd_total"]).to eq 350000
      end
    end
  end
end

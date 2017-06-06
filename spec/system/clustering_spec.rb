require 'spec_helper'
require 'httparty'

RSpec.describe "RabbitMQ cluster configuration" do

  let(:manifest) { environment.bosh_manifest }
  let(:nb_of_rmq_instances) { manifest.job('rmq').instances }
  let(:nb_of_rmq_instances) { manifest.job('rmq').instances }
  let(:rmq_username) { manifest.property('rabbitmq-server.administrators.management.username') }
  let(:rmq_password) { manifest.property('rabbitmq-server.administrators.management.password') }
  let(:rmq_management_ui_url) { manifest.property('rabbitmq-broker.rabbitmq.management_domain') }

  describe "uses native clustering" do
    before(:all) do
      modify_and_deploy_manifest do |manifest|
        manifest['properties']['rabbitmq-server']['use_native_clustering_formation'] = true
      end
    end

    it "should have all the nodes running on the cluster" do
      nodes = get_nodes(rmq_management_ui_url, rmq_username, rmq_password)

      expect(nodes.size).to eql(nb_of_rmq_instances)
      nodes.each { |node| expect(node['running']).to be true }
    end

    it "should not have the clusterer plugin" do
      nodes = get_nodes(rmq_management_ui_url, rmq_username, rmq_password)
      nodes.each { |node| expect(node['enabled_plugins']).not_to include "rabbitmq_clusterer" }
    end

    after(:all) do
      bosh_director.deploy(environment.bosh_manifest.path)
    end
  end

  # describe "uses clusterer plugin" do
  #   before(:all) do
  #     modify_and_deploy_manifest do |manifest|
  #       manifest['properties']['rabbitmq-server']['use_native_clustering_formation'] = false
  #     end
  #   end

  #   it "should have all the nodes running on the cluster" do
  #     nodes = get_nodes(rmq_management_ui_url, rmq_username, rmq_password)

  #     expect(nodes.size).to eql(nb_of_rmq_instances)
  #     nodes.each { |node| expect(node['running']).to be true }
  #   end

  #   it "should have the clusterer plugin" do
  #     nodes = get_nodes(rmq_management_ui_url, rmq_username, rmq_password)
  #     nodes.each { |node| expect(node['enabled_plugins']).to include "rabbitmq_clusterer" }
  #   end

  #   after(:all) do
  #     bosh_director.deploy(environment.bosh_manifest.path)
  #   end
  # end

#   describe "no clustering property provided," do

#     before(:all) do
#       modify_and_deploy_manifest do |manifest|
#         manifest['properties']['rabbitmq-server'].delete('use_native_clustering_formation')
#       end
#     end

#     it "should have all the nodes running on the cluster" do
#       nodes = get_nodes(rmq_management_ui_url, rmq_username, rmq_password)

#       expect(nodes.size).to eql(nb_of_rmq_instances)
#       nodes.each { |node| expect(node['running']).to be true }
#     end

#     it "should have the clusterer plugin" do
#       nodes = get_nodes(rmq_management_ui_url, rmq_username, rmq_password)
#       nodes.each { |node| expect(node['enabled_plugins']).to include "rabbitmq_clusterer" }
#     end

#     after(:all) do
#       bosh_director.deploy(environment.bosh_manifest.path)
#     end
#   end
end

def get_nodes(management_url, username, password)
  auth = {:username => username, :password => password}
  response = HTTParty.get("https://#{management_url}/api/nodes", :verify => false, :basic_auth => auth)
  JSON.parse(response.body)
end

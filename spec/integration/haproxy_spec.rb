require 'spec_helper'

require 'httparty'

RSpec.describe 'Load balancing' do
  rmq_nodes = [0, 1, 2].shuffle

  context "given a RabbitMQ cluster with #{rmq_nodes.size} nodes" do
    rmq_nodes.each do |node|
      rmq_instance = bosh.indexed_instance('rmq', node)

      context "when I take the node #{node + 1} down" do
        before(:each) do
          bosh.stop(rmq_instance, true)
        end

        context 'but the other nodes remain up' do
          it 'then managment UI is still accessible' do
            response = HTTParty.get(rabbitmq_api_url)

            expect(response.code).to be(200)
            expect(response.body).to include('RabbitMQ Management')
          end
        end

        after(:each) do
          bosh.start(rmq_instance)
        end
      end
    end
  end
end

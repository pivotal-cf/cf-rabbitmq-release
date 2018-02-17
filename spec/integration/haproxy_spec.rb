require 'spec_helper'

require 'httparty'

RSpec.describe 'haproxy' do
  [0, 1].each do |job_index|
    context "when the job rmq/#{job_index} is down" do
      before(:all) do
        rmq_instance = bosh.indexed_instance('rmq', job_index)
        bosh.stop(rmq_instance)
      end

      after(:all) do
        rmq_instance = bosh.indexed_instance('rmq', job_index)
        bosh.start(rmq_instance)
      end

      it 'I can still access the managment UI' do
        res = HTTParty.get(rabbitmq_api_url)

        expect(res.code).to eql(200)
        expect(res.body).to include('RabbitMQ Management')
      end
    end
  end
end

require 'spec_helper'

require 'httparty'

RSpec.describe "haproxy" do
  [0, 1].each do |job_index|
    context "when the job rmq/#{job_index} is down" do
      before(:all) do
        bosh.stop("rmq/#{job_index}")
      end

      after(:all) do
        bosh.start("rmq/#{job_index}")
      end

      it 'I can still access the managment UI' do
        res = HTTParty.get(rabbitmq_api_url)

        expect(res.code).to eql(200)
        expect(res.body).to include('RabbitMQ Management')
      end
    end
  end
end

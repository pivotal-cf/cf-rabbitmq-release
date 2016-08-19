require 'spec_helper'

require 'prof/test_app'
require 'prof/marketplace_service'
require 'prof/service_instance'
require 'prof/cloud_foundry'

require 'net/http'

RSpec.describe "haproxy" do

  let(:service_name) { environment.bosh_manifest.property('rabbitmq-broker.service.name') }

  let(:service) do
    Prof::MarketplaceService.new(
      name: service_name,
      plan: 'standard'
    )
  end

  [0, 1].each do |job_index|
    context "when the job rmq/#{job_index} is down", :pushes_cf_app do
      before(:all) do
        `bosh -n stop rmq #{job_index} --force`
      end

      after(:all) do
        `bosh -n start rmq #{job_index} --force`
      end

      it "is still possible to read and write to a queue" do
        cf.push_app_and_bind_with_service(test_app, service) do |app, _|
          uri = URI("#{app.url}/services/rabbitmq/protocols/amqp091")

          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
          res = http.request_get(uri.request_uri)

          expect(res.code).to eql("200")
          expect(res.body).to include("amq.gen")
        end
      end
    end
  end
end

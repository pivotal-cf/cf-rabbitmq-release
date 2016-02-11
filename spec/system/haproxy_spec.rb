require 'spec_helper'

require 'prof/test_app'
require 'prof/marketplace_service'
require 'prof/service_instance'
require 'prof/cloud_foundry'

require 'net/http'

describe "haproxy" do

  let(:service_name) { environment.bosh_manifest.property('rabbitmq-broker.service.name') }

  let(:service) do
    Prof::MarketplaceService.new(
      name: service_name,
      plan: 'standard'
    )
  end

  %w(rmq_z1 rmq_z2).each do |job_name|
    context "when the job #{job_name}/0 is down", :pushes_cf_app do
      before(:all) do
        bosh_director.stop(job_name, 0)
      end

      after(:all) do
        bosh_director.start(job_name, 0)
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

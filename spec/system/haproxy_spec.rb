require 'spec_helper'

require 'prof/test_app'
require 'prof/marketplace_service'
require 'prof/service_instance'
require 'prof/cloud_foundry'

require 'net/http'

RSpec.describe "haproxy" do

  let(:management_uri) { 'https://' + environment.bosh_manifest.property('rabbitmq-broker.rabbitmq.management_domain') }

  [0, 1].each do |job_index|
    context "when the job rmq/#{job_index} is down" do
      before(:all) do
        `bosh -n stop rmq #{job_index} --force`
      end

      after(:all) do
        `bosh -n start rmq #{job_index} --force`
      end

      it 'I can still access the managment UI' do
        uri = URI(management_uri)

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        res = http.request_get(uri.request_uri)

        expect(res.code).to eql('200')
        expect(res.body).to include('RabbitMQ Management')
      end
    end
  end
end

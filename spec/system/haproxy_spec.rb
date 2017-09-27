require 'spec_helper'

require 'httparty'

RSpec.describe "haproxy" do

  let(:management_uri) {
    instance_group = manifest['instance_groups'].select{ |instance_group| instance_group['name'] == 'haproxy' }.first
    route_registrar_job =  instance_group['jobs'].select{ |job| job['name'] == 'route_registrar'}.first
    route_registrar_job['properties']['route_registrar']['routes'].first['uris'].first
  }

  [0, 1].each do |job_index|
    context "when the job rmq/#{job_index} is down" do
      before(:all) do
        bosh_director.stop('rmq', job_index)
      end

      after(:all) do
        bosh_director.start('rmq', job_index)
      end

      it 'I can still access the managment UI' do
        res = HTTParty.get("http://#{management_uri}")

        expect(res.code).to eql(200)
        expect(res.body).to include('RabbitMQ Management')
      end
    end
  end
end

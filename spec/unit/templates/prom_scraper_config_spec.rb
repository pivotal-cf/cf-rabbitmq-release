require 'spec_helper'
require 'bosh/template/test'

RSpec.describe 'Configuration', template: true do
  let(:release) { Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '../../..')) }
  let(:job) { release.job('rabbitmq-server') }
  let(:template) { job.template('config/prom_scraper_config.yml') }
  let(:instance) { Bosh::Template::Test::InstanceSpec.new(ip: '1.1.1.1', address: 'instance-1.example.bosh') }
  let(:link_instances) { [] }
  let(:link) { Bosh::Template::Test::Link.new(name: 'rabbitmq-server', instances: link_instances) }
  let(:manifest) { { 'rabbitmq-server' => {} } }
  let(:rendered_template) { template.render(manifest, spec: instance, consumes: [link]) }

  describe 'Prom Scraper Config' do
    it 'sets the port to the rabbitmq prometheus port' do
      expect(rendered_template).to include('port: 15692')
    end

    it 'sets the scheme to http' do
      expect(rendered_template).to include('scheme: http')
    end

    it 'sets server name to localhost' do
      expect(rendered_template).to include('server_name: localhost')
    end

    context 'when cluster_name is provided' do 
      it 'source_id includes the cluster name' do
        manifest['rabbitmq-server']['cluster_name'] = 'ha-cluster'
        expect(rendered_template).to include('source_id: ha-cluster')
      end
    end

    context 'when cluster_name is not provided' do
      it 'source_id is set to rabbit@localhost' do
        expect(rendered_template).to include('source_id: rabbit@localhost')
      end
    end
  
    context 'when create_swap_delete is true' do
      before(:each) do
        manifest['rabbitmq-server']['create_swap_delete'] = true
      end

      it 'sets the instance id to the dns address' do
        expect(rendered_template).to include("instance_id: 'rabbit@instance-1.example.bosh'\n")
      end
    end

    context 'when create_swap_delete is false' do
      it 'sets the instance id to the ip address' do
        expect(rendered_template).to include("instance_id: 'rabbit@#{Digest::MD5.hexdigest('1.1.1.1')}'\n")
      end
    end
  end
end


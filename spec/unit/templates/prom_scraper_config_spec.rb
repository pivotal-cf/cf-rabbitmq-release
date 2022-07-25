require 'spec_helper'
require 'bosh/template/test'

RSpec.describe 'Configuration', template: true do
  let(:release) { Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '../../..')) }
  let(:job) { release.job('rabbitmq-server') }
  let(:template) { job.template('config/prom_scraper_config.yml') }
  let(:instance) { Bosh::Template::Test::InstanceSpec.new(ip: '1.1.1.1', address: 'instance-1.example.bosh') }
  let(:link_instances) { [] }
  let(:link) { Bosh::Template::Test::Link.new(name: 'rabbitmq-server', instances: link_instances) }
  let(:dns_link) { Bosh::Template::Test::Link.new(name: 'rabbitmq-server-address', address: 'my-rabbitmq.dns.name') }
  let(:manifest) { { 'rabbitmq-server' => {} } }
  let(:rendered_template) { template.render(manifest, spec: instance, consumes: [link, dns_link]) }

  describe 'Prom Scraper Config' do
    context 'when management has TLS enabled' do
      it 'sets scheme to https' do
        manifest['rabbitmq-server']['management_tls'] = { 'enabled' => true }
        expect(rendered_template).to include('scheme: https')
      end

      it 'sets the port to the rabbitmq prometheus TLS port' do
        manifest['rabbitmq-server']['management_tls'] = { 'enabled' => true }
        expect(rendered_template).to include('port: 15691')
      end
    end

    context 'when management has TLS disabled' do
      it 'sets the port to the rabbitmq prometheus port' do
      expect(rendered_template).to include('port: 15692')
    end

      it 'sets scheme to http' do
        expect(rendered_template).to include('scheme: http')
      end
    end

    context 'when a dns link is present' do
      it 'sets server name to rabbitmq server dns name' do
        expect(rendered_template).to include('server_name: my-rabbitmq.dns.name')
      end
    end

    context 'when a dns link is not present' do
      let(:rendered_template_no_dns) { template.render(manifest, spec: instance, consumes: [link]) }
      it 'sets server name to localhost' do
        expect(rendered_template_no_dns).to include('server_name: localhost')
      end
    end

    context 'when prom_scraper labels are set' do
      it 'adds the labels to the prom_scraper_config file' do
        manifest['rabbitmq-server']['prom_scraper_labels'] = { 'key1' => 'value1', 'key2' => 'value2' }
        expect(rendered_template).to include('labels:')
        expect(rendered_template).to include('  key1: value1')
        expect(rendered_template).to include('  key2: value2')
      end
    end

    context 'when source_id is explicitly provided' do
      it 'sets the source_id without modification' do
        manifest['rabbitmq-server']['prom_scraper_source_id'] = 'prom_scraper_source_id'
        expect(rendered_template).to include('source_id: prom_scraper_source_id')
      end
    end

    context 'when ensure_log_cache_compatibility is  provided' do
      it 'errors if source_id is greater than 48 characters in length' do
        manifest['rabbitmq-server']['prom_scraper_source_id'] = 'source_id_longer_than_48_characters---------------'
        manifest['rabbitmq-server']['ensure_log_cache_compatibility'] = true
        expect{ rendered_template }.to raise_error 'prom_scraper source_id must be 48 characters or less'
      end

      it 'sets the instance_id to the vm index' do
        manifest['rabbitmq-server']['prom_scraper_source_id'] = 'source_id_and_vm_index'
        manifest['rabbitmq-server']['ensure_log_cache_compatibility'] = true
        expect(rendered_template).to include('instance_id: xxxxxx-xxxxxxxx-xxxxx')
        expect(rendered_template).to_not include('instance_id: rabbit@')
      end
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

    context 'when using the aggregated metrics' do
      it 'sets scrape path accordingly' do
        expect(rendered_template).to include('path: /metrics')
      end
    end

    context 'when using the detailed metrics' do
      context 'when the custom scrape query is unset' do
        it 'sets scrape path accordingly' do
          template = job.template('config/prom_scraper_detailed_config.yml')
          rendered_template = template.render(manifest, spec: instance, consumes: [link])
          expect(rendered_template).to include('path: /metrics/detailed')
        end
      end

      context 'when the custom scrape query is unset' do
        before(:each) do
          manifest['rabbitmq-server']['prom_scraper_detailed_endpoint_query'] = '?foo=bar&baz=vhost'
        end

        it 'sets scrape path accordingly' do
          template = job.template('config/prom_scraper_detailed_config.yml')
          rendered_template = template.render(manifest, spec: instance, consumes: [link])
          expect(rendered_template).to include('path: /metrics/detailed?foo=bar&baz=vhost')
        end
      end
    end

    context 'when create_swap_delete is false' do
      it 'sets the instance id to the ip address' do
        expect(rendered_template).to include("instance_id: 'rabbit@#{Digest::MD5.hexdigest('1.1.1.1')}'\n")
      end
    end
  end
end


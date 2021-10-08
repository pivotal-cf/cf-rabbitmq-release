require 'spec_helper'
require 'bosh/template/renderer'

RSpec.describe 'Configuration', template: true do
  let(:rendered_template) do
    compiled_template('rabbitmq-server', 'config-files/16-stream.conf', manifest_properties)
  end

  context 'when rabbitmq_stream plugin and SSL are enabled' do
    let(:manifest_properties) do
      {
        'rabbitmq-server' => {
          'version' => '3.9',
          'plugins' => ['rabbitmq_stream'],
          'ssl' => {
            'enabled' => true,
            'cacert' => 'fake CA cert',
            'cert' => 'fake cert',
            'key' => 'fake key',
            'verification_depth' => 3,
            'versions' => ['tlsv1.2', 'tlsv1.1'],
            'disable_non_ssl_listeners' => false
          },
          'stream' => {
            'advertised_host' => 'external_host',
            'advertised_tls_port' => 'external_tls_port'
          }
        }
      }
    end
    it 'renders stream config' do
      expect(rendered_template).to include('stream.listeners.ssl.default = 5551')
      expect(rendered_template).not_to include('stream.listeners.tcp = none')
      expect(rendered_template).to include('stream.advertised_host = external_host')
      expect(rendered_template).to include('stream.advertised_tls_port = external_tls_port')
    end

    context 'when disable_non_ssl_listeners is true' do
      before do
        manifest_properties['rabbitmq-server']['ssl']['disable_non_ssl_listeners'] = true
      end
      it 'disables Stream TCP listeners' do
        expect(rendered_template).to include('stream.listeners.ssl.default = 5551')
        expect(rendered_template).to include('stream.listeners.tcp = none')
      end
    end
  end

  context 'when rabbitmq_stream plugin is disabled' do
    let(:manifest_properties) do
      {
        'rabbitmq-server' => {
          'version' => '3.9',
          'plugins' => [''],
          'ssl' => {
            'enabled' => true,
            'cacert' => 'fake CA cert',
            'cert' => 'fake cert',
            'key' => 'fake key',
            'verification_depth' => 3,
            'versions' => ['tlsv1.2', 'tlsv1.1'],
            'disable_non_ssl_listeners' => true
          }
        }
      }
    end

    it 'stream plugin is not configured' do
      expect(rendered_template).not_to include('stream')
    end
  end

  context 'when version is 3.8 and plugins contains "rabbitmq_stream"' do
    let(:manifest_properties) do
      {
        'rabbitmq-server' => {
          'version' => '3.8',
          'plugins' => ['rabbitmq_stream'],
          'ssl' => {
            'enabled' => true,
            'cacert' => 'fake CA cert',
            'cert' => 'fake cert',
            'key' => 'fake key',
            'verification_depth' => 3,
            'versions' => ['tlsv1.2', 'tlsv1.1'],
            'disable_non_ssl_listeners' => true
          }
        }
      }
    end

    it 'stream plugin is not configured' do
      expect(rendered_template).not_to include('stream.listeners')
    end
  end

  context 'when stream.advertised_host and stream.advertised_port are configured' do
    let(:manifest_properties) do
      {
        'rabbitmq-server' => {
          'version' => '3.9',
          'plugins' => ['rabbitmq_stream'],
          'stream' => {
            'advertised_host' => 'external_host',
            'advertised_port' => 'external_port'
          }
        }
      }
    end

    it 'stream plugin is configured accordingly' do
      expect(rendered_template).to include('stream.advertised_host = external_host')
      expect(rendered_template).to include('stream.advertised_port = external_port')
    end
  end
end

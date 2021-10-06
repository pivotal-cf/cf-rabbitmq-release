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
          'plugins' => ['rabbitmq_stream'],
          'ssl' => {
            'enabled' => true,
            'cacert' => 'fake CA cert',
            'cert' => 'fake cert',
            'key' => 'fake key',
            'verification_depth' => 3,
            'versions' => ['tlsv1.2', 'tlsv1.1'],
            'disable_non_ssl_listeners' => false
          }
        }
      }
    end
    it 'renders stream config' do
      expect(rendered_template).to include('stream.listeners.ssl.default = 5551')
    end

    context 'when disable_non_ssl_listeners is true' do
      before do
        manifest_properties['rabbitmq-server']['ssl']['disable_non_ssl_listeners'] = true
      end
      it 'disables Stream TCP listeners' do
        expect(rendered_template).to include('stream.listeners.tcp = none')
      end
    end
  end
end

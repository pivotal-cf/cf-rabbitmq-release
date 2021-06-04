require 'spec_helper'
require 'bosh/template/renderer'

RSpec.describe 'Inter-node TLS Configuration', template: true do
  let(:rendered_template) {
    compiled_template('rabbitmq-server', 'config-files/inter_node_tls.config', manifest_properties)
  }

  context 'certs are not provided' do
    let(:manifest_properties) do
      {
        'rabbitmq-server' => {
          'ssl' => {
            'inter_node_enabled' => true
          }
        }
      }
    end
    it 'raises an error' do
      expect{ rendered_template }.to raise_error 'Inter-node TLS cannot be enabled if not provided with all necessary TLS certificates and keys'
    end
  end

  context 'Erlang is pre-24' do
    let(:manifest_properties) do
      {
        'rabbitmq-server' => {
          'ssl' => {
            'inter_node_enabled' => true,
            'cert' => 'abcabc',
            'cacert' => 'abcabc',
            'key' => 'abcabc'
          },
          'erlang_major_version' => 23
        }
      }
    end
    it 'raises an error' do
      expect{ rendered_template }.to raise_error 'Inter-node TLS requires Erlang 24 or later'
    end
  end

  context 'Erlang is post-24 and certs are provided' do
    let(:manifest_properties) do
      {
        'rabbitmq-server' => {
          'ssl' => {
            'enabled' => 'false',
            'inter_node_enabled' => true,
            'cert' => 'abcabc',
            'cacert' => 'abcabc',
            'key' => 'abcabc'
          },
          'erlang_major_version' => 24
        }
      }
    end
    it 'renders the config file' do
      expect(rendered_template).to include('{cacertfile, "/var/vcap/jobs/rabbitmq-server/etc/cacert.pem"}')
      expect(rendered_template).to include('{certfile,   "/var/vcap/jobs/rabbitmq-server/etc/cert.pem"}')
      expect(rendered_template).to include('{keyfile,    "/var/vcap/jobs/rabbitmq-server/etc/key.pem"}')
    end
  end

end

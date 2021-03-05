require 'spec_helper'
require 'bosh/template/renderer'

RSpec.describe 'Configuration', template: true do
  let(:rendered_template) {
    compiled_template('rabbitmq-server', 'config-files/15-webMQTT.conf', manifest_properties)
  }

  context 'when rabbitmq_web_mqtt plugin and SSL are enabled' do
    let(:manifest_properties) do
      {
        'rabbitmq-server' => {
          'plugins' => ['rabbitmq_web_mqtt'],
          'ssl' => {
            'enabled' => true,
            'cacert' => 'fake CA cert',
            'cert' => 'fake cert',
            'key' => 'fake key',
            'verification_depth' => 3,
            'versions' => ['tlsv1.2','tlsv1.1'],
            'disable_non_ssl_listeners' => false,
          }
        }
      }
    end
    it 'renders web_mqtt config' do
      expect(rendered_template).to include('web_mqtt.ssl.port = 15676')
      expect(rendered_template).to include('web_mqtt.ssl.cacertfile = /var/vcap/jobs/rabbitmq-server/etc/cacert.pem')
      expect(rendered_template).to include('web_mqtt.ssl.certfile = /var/vcap/jobs/rabbitmq-server/etc/cert.pem')
      expect(rendered_template).to include('web_mqtt.ssl.keyfile = /var/vcap/jobs/rabbitmq-server/etc/key.pem')
      expect(rendered_template).to include('web_mqtt.ssl.depth = 3')
      expect(rendered_template).to include('web_mqtt.ssl.versions.1 = tlsv1.2')
      expect(rendered_template).to include('web_mqtt.ssl.versions.2 = tlsv1.1')
      expect(rendered_template).not_to include('web_mqtt.tcp.listener')
      expect(rendered_template).not_to include('web_mqtt.ssl.ciphers')
    end

    context 'when disable_non_ssl_listeners is true' do
      before do
        manifest_properties['rabbitmq-server']['ssl']['disable_non_ssl_listeners'] = true
      end
      it 'disables MQTT TCP listeners' do
        expect(rendered_template).to include('web_mqtt.tcp.listener = none')
      end
    end

    context 'when ciphers are set' do
      before do
        manifest_properties['rabbitmq-server']['ssl']['ciphers'] = ['cipher1', 'cipher2']
      end
      it 'renders MQTT SSL ciphers' do
        expect(rendered_template).to include('web_mqtt.ssl.ciphers.1 = cipher1')
        expect(rendered_template).to include('web_mqtt.ssl.ciphers.2 = cipher2')
      end
    end
  end
end

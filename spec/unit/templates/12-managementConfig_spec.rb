require 'spec_helper'
require 'bosh/template/renderer'

RSpec.describe 'Configuration', template: true do
  let(:rendered_template) {
    compiled_template('rabbitmq-server', 'config-files/12-managementConfig.conf', manifest_properties)
  }

  context 'when management-over-tls is enabled' do
		let(:manifest_properties) { {
				'rabbitmq-server' => {
          'management_tls' => {
            'enabled':true
          }
		    }
      } 
    }
    it 'renders the management TLS config in Cuttlefish format' do
      expect(rendered_template).to include('management.ssl.port = 15671')
      expect(rendered_template).to include('management.ssl.cacertfile = /var/vcap/jobs/rabbitmq-server/etc/management-cacert.pem')
      expect(rendered_template).to include('management.ssl.certfile = /var/vcap/jobs/rabbitmq-server/etc/management-cert.pem')
      expect(rendered_template).to include('management.ssl.keyfile = /var/vcap/jobs/rabbitmq-server/etc/management-key.pem')
      expect(rendered_template).not_to include('management.tcp.port = 15672')
      expect(rendered_template).to include('management.http_log_dir = "/var/vcap/sys/log/rabbitmq-server/management-ui"')
    end
  end

  context 'when management-over-tls is disabled' do
    let(:manifest_properties) do
      {
        'rabbitmq-server' => {
          'oauth' => {
            'enabled': false
          }
        }
      }
    end
    it 'renders the default management config' do
      expect(rendered_template).not_to include('management.ssl.port = 15671')
      expect(rendered_template).not_to include('management.ssl.cacertfile = /var/vcap/jobs/rabbitmq-server/etc/management-cacert.pem')
      expect(rendered_template).not_to include('management.ssl.certfile = /var/vcap/jobs/rabbitmq-server/etc/management-cert.pem')
      expect(rendered_template).not_to include('management.ssl.keyfile = /var/vcap/jobs/rabbitmq-server/etc/management-key.pem')
      expect(rendered_template).to include('management.tcp.port = 15672')
      expect(rendered_template).to include('management.http_log_dir = "/var/vcap/sys/log/rabbitmq-server/management-ui"')
    end
  end

  context 'when management-over-tls config is not provided' do
    let(:manifest_properties) do
      {
        'rabbitmq-server' => {}
      }
    end
    it 'renders the default management config' do
      expect(rendered_template).not_to include('management.ssl.port = 15671')
      expect(rendered_template).not_to include('management.ssl.cacertfile = /var/vcap/jobs/rabbitmq-server/etc/management-cacert.pem')
      expect(rendered_template).not_to include('management.ssl.certfile = /var/vcap/jobs/rabbitmq-server/etc/management-cert.pem')
      expect(rendered_template).not_to include('management.ssl.keyfile = /var/vcap/jobs/rabbitmq-server/etc/management-key.pem')
      expect(rendered_template).to include('management.tcp.port = 15672')
      expect(rendered_template).to include('management.http_log_dir = "/var/vcap/sys/log/rabbitmq-server/management-ui"')
    end
  end
end

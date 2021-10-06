require 'spec_helper'
require 'bosh/template/renderer'

RSpec.describe 'Configuration', template: true do
  let(:rendered_template) {
    compiled_template('rabbitmq-server', 'config-files/11-tlsConfig.conf', manifest_properties)
  }

  context 'when tls is enabled' do
		let(:manifest_properties) { {
				'rabbitmq-server' => {
          'ssl' => {
            'enabled':true,
            'cacert': 'FAKECACERT',
            'cert': 'FAKECERT',
            'key': 'FAKEKEY',
            'versions': ["tlsv1.3", "tlsv1.2"],
            'ciphers': ["TOTALLYLEGITCIPHER256", "TOTALLYLEGITCIPHER512"],
            'verify': false,
            'verification_depth': 7,
            'fail_if_no_peer_cert': false,
            'disable_non_ssl_listeners': false
          }
		    }
      } 
    }
    it 'renders the TLS config in Cuttlefish format' do
      expect(rendered_template).to include('listeners.ssl.1 = 5671')
      expect(rendered_template).to include('mqtt.listeners.ssl.1 = 8883')
      expect(rendered_template).to include('stomp.listeners.ssl.1 = 61614')

      expect(rendered_template).to include('ssl_options.verify = verify_none')
      expect(rendered_template).to include('ssl_options.cacertfile = /var/vcap/jobs/rabbitmq-server/etc/cacert.pem')
      expect(rendered_template).to include('ssl_options.certfile = /var/vcap/jobs/rabbitmq-server/etc/cert.pem')
      expect(rendered_template).to include('ssl_options.keyfile = /var/vcap/jobs/rabbitmq-server/etc/key.pem')
      expect(rendered_template).to include('ssl_options.depth = 7')
      expect(rendered_template).to include('ssl_options.fail_if_no_peer_cert = false')
      expect(rendered_template).to include('ssl_options.versions.1 = tlsv1.3')
      expect(rendered_template).to include('ssl_options.versions.2 = tlsv1.2')
      expect(rendered_template).to include('ssl_options.ciphers.1 = TOTALLYLEGITCIPHER256')
      expect(rendered_template).to include('ssl_options.ciphers.2 = TOTALLYLEGITCIPHER512')
    end
  end

  context 'when an unsupported TLS version is provided' do
		let(:manifest_properties) { {
				'rabbitmq-server' => {
          'ssl' => {
            'enabled':true,
            'versions': ["tlsv1", "sslv3"]
          }
		    }
      } 
    }
    it 'raises a templating error' do
      expect{ rendered_template }.to raise_error 'sslv3 is a not supported tls version'
    end
  end

  context 'when tls 1.3 is enabled along with tls 1.1 or tls 1.0' do
    context 'when tls 1.3 is enabled along with tls 1.1' do
      let(:manifest_properties) { {
          'rabbitmq-server' => {
            'ssl' => {
              'enabled':true,
              'versions':['tlsv1.3', 'tlsv1.2', 'tlsv1.1'],
            }
          }
        }
      }
      it 'raises an error' do
        expect { rendered_template }.to \
          raise_error 'TLS 1.3 cannot be enabled along with TLS 1.1 and TLS 1.0'
      end
    end

    context 'when tls 1.3 is enabled along with tls 1.1' do
      let(:manifest_properties) { {
          'rabbitmq-server' => {
            'ssl' => {
              'enabled':true,
              'versions':['tlsv1.3', 'tlsv1.2', 'tlsv1'],
            }
          }
        }
      }
      it 'raises an error' do
        expect { rendered_template }.to \
          raise_error 'TLS 1.3 cannot be enabled along with TLS 1.1 and TLS 1.0'
      end
    end
  end

  context 'when an invalid cipher is provided' do
		let(:manifest_properties) { {
				'rabbitmq-server' => {
          'ssl' => {
            'enabled':true,
            'ciphers': ['TOTALLYLEGITCIPHER256', 'an_invalid_!@#$']
          }
		    }
      } 
    }
    it 'raises a templating error' do
      expect{ rendered_template }.to raise_error 'an_invalid_!@#$ is not a valid cipher suite'
    end
  end

  context 'when a valid TLS 1.3 cipher is provided' do
		let(:manifest_properties) { {
				'rabbitmq-server' => {
          'ssl' => {
            'enabled':true,
            'ciphers': ['TOTALLYLEGITCIPHER256', 'TLS1_3_VALID_CIPHER']
          }
		    }
      }
    }
    it 'includes the valid cipher' do
      expect(rendered_template).to include('ssl_options.ciphers.1 = TOTALLYLEGITCIPHER256')
      expect(rendered_template).to include('ssl_options.ciphers.2 = TLS1_3_VALID_CIPHER')
    end
  end

  context 'when non-TLS listeners are disabled' do
		let(:manifest_properties) { {
				'rabbitmq-server' => {
          'ssl' => {
            'enabled': true,
            'disable_non_ssl_listeners': true
          }
		    }
      } 
    }
    it 'provides the config to disable the listeners' do
      expect(rendered_template).to include('listeners.tcp = none')
      expect(rendered_template).to include('mqtt.listeners.tcp = none')
      expect(rendered_template).to include('stomp.listeners.tcp = none')
    end
  end

  context 'when configured to verify the peer' do
		let(:manifest_properties) { {
				'rabbitmq-server' => {
          'ssl' => {
            'enabled': true,
            'verify': true
          }
		    }
      } 
    }
    it 'provides the config to configure peer verification' do
      expect(rendered_template).to include('ssl_options.verify = verify_peer')
    end
  end

  context 'when tls config is not provided' do
    let(:manifest_properties) do
      {
        'rabbitmq-server' => {}
      }
    end
    it 'renders the empty config file' do
      expect(rendered_template).to be_empty
    end
  end
end

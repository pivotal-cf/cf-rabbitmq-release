require 'spec_helper'
require 'bosh/template/renderer'

RSpec.describe 'Configuration', template: true do
  let(:rendered_template) {
    compiled_template('rabbitmq-server', 'config-files/13-oAuth.conf', manifest_properties)
  }
  let(:rendered_signing_key) {
    compiled_template('rabbitmq-server', 'oAuth-signing-key.pem', manifest_properties)
  }

  context 'when oauth is enabled' do
		let(:manifest_properties) { {
				'rabbitmq-server' => {
          'oauth' => {
            'enabled':true,
            'resource_server_id': '5507278f-73bc-44fd-904d-03aea4add4f0',
            'client_id': '67866802-73bc-44fd-904d-03aea4add4f0',
            'client_secret': 'secret',
            'provider_url': 'https://uaa.cf.example.com',
            'oauth_scopes': 'scopes',
            'signing_key_id': 'fake-key-id',
            'signing_key': "-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA2dP+vRn+Kj+S/oGd49kq
6+CKNAduCC1raLfTH7B3qjmZYm45yDl+XmgK9CNmHXkho9qvmhdksdzDVsdeDlhK
IdcIWadhqDzdtn1hj/22iUwrhH0bd475hlKcsiZ+oy/sdgGgAzvmmTQmdMqEXqV2
B9q9KFBmo4Ahh/6+d4wM1rH9kxl0RvMAKLe+daoIHIjok8hCO4cKQQEw/ErBe4SF
2cr3wQwCfF1qVu4eAVNVfxfy/uEvG3Q7x005P3TcK+QcYgJxav3lictSi5dyWLgG
QAvkknWitpRK8KVLypEj5WKej6CF8nq30utn15FQg0JkHoqzwiCqqeen8GIPteI7
VwIDAQAB
-----END PUBLIC KEY-----"
          }
		    }
      }
    }
    it 'renders the oAuth config in Cuttlefish format' do
      expect(rendered_template).to include('auth_backends.1 = rabbit_auth_backend_oauth2')
      expect(rendered_template).to include('auth_backends.2 = rabbit_auth_backend_internal')
      expect(rendered_template).to include('management.oauth_enabled = true')
      expect(rendered_template).to include('management.oauth_client_id = 67866802-73bc-44fd-904d-03aea4add4f0')
      expect(rendered_template).to include('management.oauth_client_secret = secret')
      expect(rendered_template).to include('management.oauth_provider_url = https://uaa.cf.example.com')
      expect(rendered_template).to include('management.oauth_scopes = openid 5507278f-73bc-44fd-904d-03aea4add4f0.*')
      expect(rendered_template).to include('auth_oauth2.resource_server_id = 5507278f-73bc-44fd-904d-03aea4add4f0')
      expect(rendered_template).to include('auth_oauth2.preferred_username_claims.1 = user_name')
      expect(rendered_template).not_to include('auth_oauth2.jwks_url')
      expect(rendered_template).to include('auth_oauth2.default_key = fake-key-id')
      expect(rendered_template).to include('auth_oauth2.signing_keys.fake-key-id = /var/vcap/jobs/rabbitmq-server/etc/oAuth-signing-key.pem')

      expect(rendered_signing_key).to include('-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA2dP+vRn+Kj+S/oGd49kq
6+CKNAduCC1raLfTH7B3qjmZYm45yDl+XmgK9CNmHXkho9qvmhdksdzDVsdeDlhK
IdcIWadhqDzdtn1hj/22iUwrhH0bd475hlKcsiZ+oy/sdgGgAzvmmTQmdMqEXqV2
B9q9KFBmo4Ahh/6+d4wM1rH9kxl0RvMAKLe+daoIHIjok8hCO4cKQQEw/ErBe4SF
2cr3wQwCfF1qVu4eAVNVfxfy/uEvG3Q7x005P3TcK+QcYgJxav3lictSi5dyWLgG
QAvkknWitpRK8KVLypEj5WKej6CF8nq30utn15FQg0JkHoqzwiCqqeen8GIPteI7
VwIDAQAB
-----END PUBLIC KEY-----')
    end
  end

  context 'oauth config is enabled and jwks endpoint is used' do
		let(:manifest_properties) { {
				'rabbitmq-server' => {
          'oauth' => {
            'enabled':true,
            'resource_server_id': '5507278f-73bc-44fd-904d-03aea4add4f0',
            'client_id': '67866802-73bc-44fd-904d-03aea4add4f0',
            'client_secret': 'secret',
            'provider_url': 'https://uaa.cf.example.com',
            'oauth_scopes': 'scopes',
            'jwks_url': 'https://uaa.cf.example.com/token_keys',
            'signing_key_id': 'fake-key-id',
            'signing_key': "-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA2dP+vRn+Kj+S/oGd49kq
6+CKNAduCC1raLfTH7B3qjmZYm45yDl+XmgK9CNmHXkho9qvmhdksdzDVsdeDlhK
IdcIWadhqDzdtn1hj/22iUwrhH0bd475hlKcsiZ+oy/sdgGgAzvmmTQmdMqEXqV2
B9q9KFBmo4Ahh/6+d4wM1rH9kxl0RvMAKLe+daoIHIjok8hCO4cKQQEw/ErBe4SF
2cr3wQwCfF1qVu4eAVNVfxfy/uEvG3Q7x005P3TcK+QcYgJxav3lictSi5dyWLgG
QAvkknWitpRK8KVLypEj5WKej6CF8nq30utn15FQg0JkHoqzwiCqqeen8GIPteI7
VwIDAQAB
-----END PUBLIC KEY-----"
          }
		    }
      }
    }
    it 'renders the oAuth config in Cuttlefish format' do
      expect(rendered_template).to include('auth_backends.1 = rabbit_auth_backend_oauth2')
      expect(rendered_template).to include('auth_backends.2 = rabbit_auth_backend_internal')
      expect(rendered_template).to include('management.oauth_enabled = true')
      expect(rendered_template).to include('management.oauth_client_id = 67866802-73bc-44fd-904d-03aea4add4f0')
      expect(rendered_template).to include('management.oauth_client_secret = secret')
      expect(rendered_template).to include('management.oauth_provider_url = https://uaa.cf.example.com')
      expect(rendered_template).to include('management.oauth_scopes = openid 5507278f-73bc-44fd-904d-03aea4add4f0.*')
      expect(rendered_template).to include('auth_oauth2.resource_server_id = 5507278f-73bc-44fd-904d-03aea4add4f0')
      expect(rendered_template).to include('auth_oauth2.preferred_username_claims.1 = user_name')
      expect(rendered_template).to include('auth_oauth2.jwks_url = https://uaa.cf.example.com/token_keys')
    end
  end

  context 'oauth config is disabled' do
    let(:manifest_properties) do
      {
        'rabbitmq-server' => {
          'oauth' => {
            'enabled': false
          }
        }
      }
    end
    it 'renders the empty config file' do
      expect(rendered_template).to be_empty
      expect(rendered_signing_key).to be_empty
    end
  end

  context 'oauth config is not provided' do
    let(:manifest_properties) do
      {
        'rabbitmq-server' => {}
      }
    end
    it 'renders the empty config file' do
      expect(rendered_template).to be_empty
      expect(rendered_signing_key).to be_empty
    end
  end
end

RSpec.describe 'advanced.config file generation', template: true do
	let(:output) do
    compiled_template('rabbitmq-server', 'config-files/advanced.config', manifest_properties).strip
	end

  context 'when custom advanced.config is provided' do
		let(:manifest_properties) { {
				'rabbitmq-server' => {
          'override_advanced_config': 'WwogIHtyYWJiaXQsIFsKICAgICAge3RjcF9saXN0ZW5lcnMsIFs1NjczXX0KICAgIF0KICB9Cl0u'
		    }
      } 
    }

		it 'sets the override config' do
			expect(output).to eq('[
  {rabbit, [
      {tcp_listeners, [5673]}
    ]
  }
].')
    end
	end

  # In previous releases, it was not possible to configure both override_advanced_config
  # and OAuth config. Since the latter has been moved to the conf.d config files,
  # only the override config should be set in this file now.
  context 'when oauth is enabled alongside advanced config' do
		let(:manifest_properties) { {
				'rabbitmq-server' => {
          'oauth' => {
            'enabled':true,
            'resource_server_id': '5507278f-73bc-44fd-904d-03aea4add4f0',
            'uaa_client_id': '67866802-73bc-44fd-904d-03aea4add4f0',
            'uaa_location': 'https://uaa.cf.example.com',
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
          },
          'override_advanced_config': 'WwogIHtyYWJiaXQsIFsKICAgICAge3RjcF9saXN0ZW5lcnMsIFs1NjczXX0KICAgIF0KICB9Cl0u'
		    }
      } 
    }

		it 'configures no oAuth config, and still configures the override advanced config' do
			expect(output).to eq('[
  {rabbit, [
      {tcp_listeners, [5673]}
    ]
  }
].')
    end
	end
end


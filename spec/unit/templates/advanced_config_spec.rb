RSpec.describe 'advanced.config file generation for oauth', template: true do
	let(:output) do
    compiled_template('rabbitmq-server', 'config-files/advanced.config', manifest_properties).strip
	end

	context 'when oauth is not defined' do
		let(:manifest_properties) { {} }

		it 'defaults to []. valid erlang config' do
			expect(output).to eq("[].")
    end
	end

	context 'when oauth is disabled' do
		let(:manifest_properties) { {
				'rabbitmq-server' => {
          'oauth' => {
            'enabled': false
          }
		    }
      } 
    }

		it 'defaults to []. valid erlang config' do
			expect(output).to eq("[].")
    end
	end

  context 'when oauth is disabled and custom advanced.config is provided' do
		let(:manifest_properties) { {
				'rabbitmq-server' => {
          'oauth' => {
            'enabled': false
          },
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

  context 'when oauth is enabled' do
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
          }
		    }
      } 
    }

		it 'configures only the oauth advanced config that does not have a Cuttlefish equivalent' do
      expect(output).to eq(File.open("spec/unit/templates/assets/expected_rabbitmq_advanced.config").read.strip)
    end
	end
end


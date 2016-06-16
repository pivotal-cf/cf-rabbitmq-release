require 'spec_helper'

RSpec.describe 'NATS', template: true do
	let(:rendered_template) do
		YAML.load(compiled_template('rabbitmq-haproxy', 'management_registrar_settings.yml', {
			'route_registrar'=> {
				'message_bus_servers'=> [
					{
						'host'=> 'awesome-host',
						'port' => '1234',
						'user'=> 'great-user',
						'password'=> 'fantastic-password',
					},
					{
						'host'=> 'rubbish-host',
						'port' => '5678',
						'user'=> 'rotten-user',
						'password'=> 'awful-password',
					},
				]
			},
			'rabbitmq-broker' => {
				'rabbitmq'=>{
					'management_ip'=>'1.2.3.4',
					'management_domain'=>'this.tld'
				},
				'registration_interval'=>'4s',
			}
		}))
	end

	it 'lists the message bus servers' do
		expect(rendered_template).to have_key('message_bus_servers')
		servers = rendered_template['message_bus_servers']

		expect(servers.length).to equal(2)

		server_one = servers[0]
		expect(server_one).to include('host'=>'awesome-host:1234')
		expect(server_one).to include('user'=>'great-user')
		expect(server_one).to include('password'=>'fantastic-password')

		server_two = servers[1]
		expect(server_two).to include('host'=>'rubbish-host:5678')
		expect(server_two).to include('user'=>'rotten-user')
		expect(server_two).to include('password'=>'awful-password')
	end

	it 'has correct routes' do
		expect(rendered_template).to have_key('routes')

		routes = rendered_template['routes']
		expect(routes.length).to equal(1)

		first_route = routes.first
		expect(first_route).to include('name' => 'this.tld')
		expect(first_route).to include('registration_interval' => '4s')
		expect(first_route).to include('port' => 15672)
		expect(first_route).to include('uris' => ['this.tld'])
	end
end

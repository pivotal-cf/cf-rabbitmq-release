require 'spec_helper'
require 'bosh/template/renderer'

RSpec.describe 'Users credentials file', template: true do
  let(:users_config) {
    compiled_template('rabbitmq-server', 'users', {
      'rabbitmq-server' => {
        'administrators' => {
          'management' => {
            'username' => 'my${SHELL}username',
            'password' => 'my${SHELL}password'
          },
          'broker' => {
            'username' => 'my${SHELL}username',
            'password' => 'my${SHELL}password'
          }
        }
      }
    })
  }

  it 'does not allow Shell injection by escaping special chars' do
    expect(users_config).to include('RMQ_OPERATOR_USERNAME=my\$\{SHELL\}username')
    expect(users_config).to include('RMQ_OPERATOR_PASSWORD=my\$\{SHELL\}password')
    expect(users_config).to include('RMQ_BROKER_USERNAME=my\$\{SHELL\}username')
    expect(users_config).to include('RMQ_BROKER_PASSWORD=my\$\{SHELL\}password')
  end
end

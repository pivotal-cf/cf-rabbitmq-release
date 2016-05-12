require 'yaml'

RSpec.describe 'rabbitmq broker config template', template: true do
	let(:output) { YAML.load(compiled_template('rabbitmq-broker', 'broker_config.yml', {})) }

	it 'does not enable operator set policy' do
		expect(output['rabbitmq']['operator_set_policy']['enabled']).to be false
	end
end



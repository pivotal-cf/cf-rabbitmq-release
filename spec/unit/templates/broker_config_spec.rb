require 'yaml'

RSpec.describe 'rabbitmq broker config template', template: true do
  let(:output) do
    template = compiled_template('rabbitmq-broker', 'broker_config.yml', {}, {
      'rabbitmq-broker' => { 'instances' => [{ 'address' => '1.2.3.4' }] },
      'rabbitmq-haproxy' => {
        'instances' => [
          { 'address' => '1.1.1.1' },
          { 'address' => '2.2.2.2' }
        ]
      }
    })
    YAML.load(template)
  end

  it 'does not enable operator set policy' do
    expect(output['rabbitmq']['operator_set_policy']['enabled']).to be false
  end
end

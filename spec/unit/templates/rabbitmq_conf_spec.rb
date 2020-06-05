require 'spec_helper'
require 'bosh/template/renderer'

RSpec.describe 'Configuration', template: true do
  let(:rendered_template) {
    compiled_template('rabbitmq-server', 'rabbitmq.conf', manifest_properties)
  }

  context 'when load_definitions is set' do
    let(:manifest_properties) do
      {
        'rabbitmq-server' => {
          'load_definitions' => {
            'vhosts' =>  [
              {'name' => 'vhost-1'}
            ]
          }
        }
      }
    end
    it 'renders load_definition path' do
      expect(rendered_template).to include("management.load_definitions = /var/vcap/jobs/rabbitmq-server/etc/definitions.json")
    end
  end

  context 'when load_definitions is empty' do
    let(:manifest_properties) { {} }
    it 'renders an empty rabbitmq.conf file' do
      expect(rendered_template).to be_empty
    end
  end
end

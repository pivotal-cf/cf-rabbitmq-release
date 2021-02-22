require 'spec_helper'
require 'bosh/template/renderer'

RSpec.describe 'Configuration', template: true do
  let(:rendered_template) {
    compiled_template('rabbitmq-server', 'config-files/50-overrideConfig.conf', manifest_properties)
  }

  context 'override config is provided' do
    let(:manifest_properties) do
      {
        'rabbitmq-server' => {
          'override_config': 'rabbit.foo.a = b
ssl.bar.c = d'
        }
      }
    end
    it 'renders the override config in the appropriate conf.d file' do
      expect(rendered_template).to include('rabbit.foo.a = b')
      expect(rendered_template).to include('ssl.bar.c = d')
    end
  end

  context 'override config is not provided' do
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

require 'spec_helper'
require 'bosh/template/renderer'

RSpec.describe 'Server version', template: true do
  let(:manifest_properties) do
    {
      'rabbitmq-server' => {
        'version' => 'fake_version'
      }
    }
  end

  let(:rendered_template) {
    compiled_template('rabbitmq-server', 'rabbitmq-server-version', manifest_properties).strip
  }

  describe 'environment variables' do
    it 'sets RMQ_SERVER_VERSION' do
      expect(rendered_template).to include("RMQ_SERVER_VERSION=fake_version")
    end
  end
end

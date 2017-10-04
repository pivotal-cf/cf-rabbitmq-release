require 'spec_helper'
require 'bosh/template/renderer'

RSpec.describe 'Configuration', template: true do
  let(:rendered_template) {
    compiled_template('rabbitmq-server', 'config')
  }

  describe 'environment variables' do
    it 'exports a RMQ_FD_LIMIT to set the global ulimit' do
      expect(rendered_template).to include("RMQ_FD_LIMIT=300000")
    end
  end
end

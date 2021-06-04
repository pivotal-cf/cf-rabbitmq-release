require 'spec_helper'
require 'bosh/template/renderer'

RSpec.describe 'Configuration', template: true do
  let(:rendered_template) {
    compiled_template('rabbitmq-server', 'config', manifest_properties)
  }

  describe 'environment variables' do
    let(:manifest_properties) do
      {
        'rabbitmq-server' => {}
      }
    end
    it 'exports a RMQ_FD_LIMIT to set the global ulimit' do
      expect(rendered_template).to include("RMQ_FD_LIMIT=300000")
    end
  end

  context 'internode TLS is enabled' do
    let(:manifest_properties) do
      {
        'rabbitmq-server' => {
          'ssl' => {
            'inter_node_enabled' => true
          }
        }
      }
    end
    context 'TLS is disabled' do
      before do
        manifest_properties['rabbitmq-server']['ssl']['enabled'] = false
      end
      it 'does contain erl args for rabbitmqctl' do
        expect(rendered_template).to include('RABBITMQ_CTL_ERL_ARGS="-proto_dist inet_tls -ssl_dist_optfile /var/vcap/jobs/rabbitmq-server/etc/inter_node_tls.config"')
      end
    end

    context 'TLS is enabled' do
      before do
        manifest_properties['rabbitmq-server']['ssl']['enabled'] = true
      end
      it 'does contain erl args for rabbitmqctl' do
        expect(rendered_template).to include('RABBITMQ_CTL_ERL_ARGS="-proto_dist inet_tls -ssl_dist_optfile /var/vcap/jobs/rabbitmq-server/etc/inter_node_tls.config"')
      end
    end
  end
end

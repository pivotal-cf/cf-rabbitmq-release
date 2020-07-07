require 'spec_helper'
require 'bosh/template/test'

RSpec.describe 'Configuration', template: true do

  let(:release) { Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '../../..')) }
  let(:job) { release.job('rabbitmq-server') }
  let(:template) { job.template('lib/rabbitmq-config-vars.bash') }
  let(:manifest) do
    {
      'rabbitmq-server' => {
        'cookie' => 'foobar1234'
      }
    }
  end
  let(:instance) { Bosh::Template::Test::InstanceSpec.new(ip: '1.1.1.1') }
  let(:link) { Bosh::Template::Test::Link.new(name:'rabbitmq-server', instances:link_instances) }

  let(:rendered_template) {
    template.render(manifest, spec: instance, consumes: [link])
  }

  describe 'nodes' do
    context 'when there is only one rabbitmq-server instance' do
      let(:link_instances) { [] }

      it 'should contain only localhost in cluster' do
        expect(rendered_template).to include("ERL_INETRC_HOSTS='{host, {1,1,1,1}, [\"e086aa137fa19f67d27b39d0eca18610\"]}.\n'")
      end
    end

    context 'when there are multiple rabbitmq-server instances' do
      let(:link_instances) do [
        Bosh::Template::Test::InstanceSpec.new(address: '1.1.1.2'),
        Bosh::Template::Test::InstanceSpec.new(address: '1.1.1.3')
      ]
      end

      it 'should contain all nodes in cluster' do
        expect(rendered_template).to include("ERL_INETRC_HOSTS='{host, {1,1,1,2}, [\"98660805cdee362a748327ad6032805b\"]}.")
        expect(rendered_template).to include("\n{host, {1,1,1,3}, [\"82e630489bbfe8340627fb3fdad6134c\"]}.\n'")
      end
    end
  end
end

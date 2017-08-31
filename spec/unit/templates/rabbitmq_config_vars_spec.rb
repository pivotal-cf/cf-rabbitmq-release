require 'spec_helper'
require 'bosh/template/renderer'

RSpec.describe 'Configuration', template: true do
  let(:rendered_template) {
    compiled_template('rabbitmq-server', 'rabbitmq-config-vars.bash', manifest_properties, links, network_properties)
  }
  let(:manifest_properties) { {} }
  let(:links) do
    {
      'rabbitmq-server' => {
        'instances' => [
          { 'address' => '1.1.1.1' },
          { 'address' => '2.2.2.2' }
        ]
      }
    }
  end
  let(:network_properties) { { blah: { ip: '127.0.0.1', default: true }}}

  describe "nodes" do
    context "when there is only one rabbitmq-server instance" do
      let(:links) do
        {
          'rabbitmq-server' => {
            'instances' => [
              { 'address' => '1.1.1.1' }
            ]
          }
        }
      end

      it "should contain only localhost in cluster" do
        expect(rendered_template).to include("ERL_INETRC_HOSTS='{host, {127,0,0,1}, [\"f528764d624db129b32c21fbca0cb8d6\"]}.\n'")
      end
    end

    context 'when there are multiple rabbitmq-server instances' do
      it "should contain all nodes in cluster" do
        expect(rendered_template).to include("ERL_INETRC_HOSTS='{host, {1,1,1,1}, [\"e086aa137fa19f67d27b39d0eca18610\"]}.")
        expect(rendered_template).to include("\n{host, {2,2,2,2}, [\"5b8656aafcb40bb58caf1d17ef8506a9\"]}.\n'")
      end
    end
  end
end

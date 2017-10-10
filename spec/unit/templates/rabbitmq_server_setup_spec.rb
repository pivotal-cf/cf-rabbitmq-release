require 'spec_helper'
require 'bosh/template/renderer'

RSpec.describe 'Configuration', template: true do
  let(:rendered_template) {
    compiled_template('rabbitmq-server', 'setup.sh', manifest_properties, links, network_properties)
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

      it "should have pause_minority" do
        expect(rendered_template).to include("cluster_args=\"$cluster_args -rabbit cluster_partition_handling pause_minority\"")
      end

      context "when is set to autoheal" do
        let(:manifest_properties) { { 'rabbitmq-server' => { 'cluster_partition_handling' => 'autoheal'} }}

        it "should have autoheal" do
          expect(rendered_template).to include("cluster_args=\"$cluster_args -rabbit cluster_partition_handling autoheal\"")
        end
      end

  describe 'SSL' do
    let(:manifest_properties) { { 'rabbitmq-server' => { 'ssl' => { 'key' => 'rabbitmq-ssl-key' } } } }
    it "should have tls 1 disabled by default" do
      expect(rendered_template).to include(ssl_options_with "['tlsv1.2','tlsv1.1']")
    end

    context 'when tlsv1 is enabled' do
      let(:manifest_properties) { { 'rabbitmq-server' => { 'ssl' => { 'key' => 'rabbitmq-ssl-key', 'versions' => ['tlsv1.2','tlsv1.1','tlsv1'] } } } }

      it "should enable tls 1" do
        expect(rendered_template).to include(ssl_options_with "['tlsv1.2','tlsv1.1','tlsv1']")
      end
    end
  end

  describe 'Disk Threshold' do
    it 'has "{mem_relative,0.4}" as default' do
      expect(rendered_template).to include('-rabbit disk_free_limit {mem_relative,0.4}')
    end

    context 'when the threshold is set' do
      let(:manifest_properties) { { 'rabbitmq-server' => { 'disk_alarm_threshold' => '20000000'} }}

      it 'has the appropriate alarm value' do
        expect(rendered_template).to include('-rabbit disk_free_limit 20000000')
      end
    end
  end
end

def ssl_options_with(tls_versions)
  'SSL_OPTIONS=" -rabbit ssl_options [{cacertfile,\\\\\"${SCRIPT_DIR}/../etc/cacert.pem\\\\\"},{certfile,\\\\\"${SCRIPT_DIR}/../etc/cert.pem\\\\\"},{keyfile,\\\\\"${SCRIPT_DIR}/../etc/key.pem\\\\\"},{verify,verify_none},{depth,5},{fail_if_no_peer_cert,false},{versions,' + tls_versions + '}]"'
end

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
        expect(rendered_template).to include('HOSTS="${HOSTS}{host, {127,0,0,1}, [\"f528764d624db129b32c21fbca0cb8d6\"]}.\n"')
      end
    end

    context 'when there are multiple rabbitmq-server instances' do
      it "should contain all nodes in cluster" do
        expect(rendered_template).to include('HOSTS="${HOSTS}{host, {1,1,1,1}, [\"e086aa137fa19f67d27b39d0eca18610\"]}.\n"')
        expect(rendered_template).to include('HOSTS="${HOSTS}{host, {2,2,2,2}, [\"5b8656aafcb40bb58caf1d17ef8506a9\"]}.\n"')
      end
    end
  end

  describe "cluster_partition_handling" do
    it "should have pause_minority" do
      expect(rendered_template).to include(cluster_partition_handling_with "pause_minority")
    end

    context "when is set to autoheal" do
      let(:manifest_properties) { { 'rabbitmq-server' => { 'cluster_partition_handling' => 'autoheal'} }}

      it "should have autoheal" do
        expect(rendered_template).to include(cluster_partition_handling_with "autoheal")
      end
    end
  end

  describe 'SSL' do
    it "should have tls 1 disabled by default" do
      expect(rendered_template).to include(ssl_options_with "['tlsv1.2','tlsv1.1']")
    end

    context 'when tlsv1 is enabled' do
      let(:manifest_properties) { { 'rabbitmq-server' => { 'ssl' => { 'security_options' => ['enable_tls1_0'] } } } }

      it "should enable tls 1" do
        expect(rendered_template).to include(ssl_options_with "['tlsv1.2','tlsv1.1',tlsv1]")
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

def cluster_partition_handling_with(policy)
  "SERVER_START_ARGS='-rabbitmq_clusterer config " + '\"${CLUSTER_CONFIG}\" -rabbit log_levels [{connection,info}] -rabbit disk_free_limit {mem_relative,0.4} -rabbit ' + "cluster_partition_handling #{policy} -rabbit halt_on_upgrade_failure false -rabbitmq_mqtt subscription_ttl 1800000"
end

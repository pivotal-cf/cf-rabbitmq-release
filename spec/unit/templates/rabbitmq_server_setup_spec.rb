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

  [true, false].each do |native_clusters|
    describe "cluster_partition_handling with native clustering set to #{native_clusters}" do
      let(:manifest_properties) { { 'rabbitmq-server' => { 'use_native_clustering_formation' => native_clusters} }}
      it "should have pause_minority" do
        expect(rendered_template).to include(cluster_partition_handling_with "pause_minority", native_clusters)
      end

      context "when is set to autoheal" do
        let(:manifest_properties) { { 'rabbitmq-server' => { 'use_native_clustering_formation' => native_clusters, 'cluster_partition_handling' => 'autoheal'} }}

        it "should have autoheal" do
          expect(rendered_template).to include(cluster_partition_handling_with "autoheal", native_clusters)
        end
      end
    end
  end

  describe 'SSL' do
    let(:manifest_properties) { { 'rabbitmq-server' => { 'ssl' => { 'key' => 'rabbitmq-ssl-key' } } } }
    it "should have tls 1 disabled by default" do
      expect(rendered_template).to include(ssl_options_with "['tlsv1.2','tlsv1.1']")
    end

    context 'when tlsv1 is enabled' do
      let(:manifest_properties) { { 'rabbitmq-server' => { 'ssl' => { 'key' => 'rabbitmq-ssl-key', 'security_options' => ['enable_tls1_0'] } } } }

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

def cluster_partition_handling_with(policy, native_clusters)
  server_start_args="    cluster_args=\""
  if ! native_clusters
    server_start_args += "-rabbitmq_clusterer config " + '\"${CLUSTER_CONFIG}\"'
  else
    stubbed_nodes = "-rabbit cluster_nodes {[$RABBITMQ_NODES_STRING],disc}"
    server_start_args += "#{stubbed_nodes}"
  end
  return server_start_args + "\"
  

  cluster_args=\"$cluster_args -rabbit log_levels [{connection,info}]\"
  cluster_args=\"$cluster_args -rabbit disk_free_limit {mem_relative,0.4}\"
  cluster_args=\"$cluster_args -rabbit cluster_partition_handling #{policy}\"
  cluster_args=\"$cluster_args -rabbit halt_on_upgrade_failure false\"
  cluster_args=\"$cluster_args -rabbitmq_mqtt subscription_ttl 1800000\"
  cluster_args=\"$cluster_args -rabbitmq_management http_log_dir \\\"${HTTP_ACCESS_LOG_DIR}\\\"\"

  SERVER_START_ARGS=\"SERVER_START_ARGS='$cluster_args\""
end

require 'spec_helper'
require 'bosh/template/renderer'

RSpec.describe 'Configuration' do
  let(:job_spec){ YAML.load_file('manifests/cf-rabbitmq-lite.yml') }

  before(:each) do
    job_spec[:networks] = { blah: { ip: '127.0.0.1', default: true }}
    job_spec[:job] = {name: 'rabbitmq'}
    job_spec['properties']['rabbitmq-server']['cluster_partition_handling'] = 'pause_minority'
  end

  describe "nodes" do
    it "should contain all nodes in cluster" do
      renderer = Bosh::Template::Renderer.new({context: job_spec.to_json})

      rendered_template = renderer.render('jobs/rabbitmq-server/templates/setup.sh.erb')

      expect(rendered_template).to include('HOSTS="${HOSTS}{host, {10,244,9,6}, [\"da3be74c053640fe92c6a39e2d7a5e46\"]}.\n"')
      expect(rendered_template).to include('HOSTS="${HOSTS}{host, {10,244,9,10}, [\"1bfd6e8e2eacf0a5ed6405a6db279bc1\"]}.\n"')
    end
  end

  describe "cluster_partition_handling" do
    it "should have pause_minority" do
      renderer = Bosh::Template::Renderer.new({context: job_spec.to_json})

      rendered_template = renderer.render('jobs/rabbitmq-server/templates/setup.sh.erb')

      expect(rendered_template).to include(cluster_partition_handling_with "pause_minority")
    end

    context "when is set to autoheal" do
      before(:each) do
        job_spec['properties']['rabbitmq-server']['cluster_partition_handling'] = 'autoheal'
      end

      it "should have autoheal" do
        renderer = Bosh::Template::Renderer.new({context: job_spec.to_json})

        rendered_template = renderer.render('jobs/rabbitmq-server/templates/setup.sh.erb')

        expect(rendered_template).to include(cluster_partition_handling_with "autoheal")
      end
    end
  end

  describe 'SSL' do

    it "should have tls 1 enabled by default" do
      renderer = Bosh::Template::Renderer.new({context: job_spec.to_json})

      rendered_template = renderer.render('jobs/rabbitmq-server/templates/setup.sh.erb')

      expect(rendered_template).to include(ssl_options_with "['tlsv1.2','tlsv1.1',tlsv1]")
    end

    it "should disable tls 1 when empty security specified" do
      job_spec['properties']['rabbitmq-server']['ssl']['security_options'] = []
      renderer = Bosh::Template::Renderer.new({context: job_spec.to_json})

      rendered_template = renderer.render('jobs/rabbitmq-server/templates/setup.sh.erb')

      expect(rendered_template).to include(ssl_options_with "['tlsv1.2','tlsv1.1']")
    end

  end
end

def ssl_options_with(tls_versions)
  'SSL_OPTIONS=" -rabbit ssl_options [{cacertfile,\\\\\"${SCRIPT_DIR}/../etc/cacert.pem\\\\\"},{certfile,\\\\\"${SCRIPT_DIR}/../etc/cert.pem\\\\\"},{keyfile,\\\\\"${SCRIPT_DIR}/../etc/key.pem\\\\\"},{verify,verify_none},{depth,10},{fail_if_no_peer_cert,false},{versions,' + tls_versions + '}]"'
end

def cluster_partition_handling_with(policy)
 "SERVER_START_ARGS='-rabbitmq_clusterer config " + '\"${CLUSTER_CONFIG}\" -rabbit log_levels [{connection,info}] -rabbit disk_free_limit 1000000 -rabbit ' + "cluster_partition_handling #{policy} -rabbit halt_on_upgrade_failure false -rabbitmq_mqtt subscription_ttl 1800000"
end


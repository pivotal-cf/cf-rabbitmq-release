require 'spec_helper'
require 'bosh/template/test'

RSpec.describe 'Configuration', template: true do
  let(:release) { Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '../../..')) }
  let(:job) { release.job('rabbitmq-server') }
  let(:template) { job.template('lib/rabbitmq-config-vars.bash') }
  let(:instance) { Bosh::Template::Test::InstanceSpec.new(ip: '1.1.1.1', address: 'instance-1.example.bosh') }
  let(:link_instances) { [] }
  let(:link) { Bosh::Template::Test::Link.new(name: 'rabbitmq-server', instances: link_instances) }
  let(:manifest) { { 'rabbitmq-server' => {} } }
  let(:rendered_template) { template.render(manifest, spec: instance, consumes: [link]) }

  describe 'ERL_INETRC_HOSTS' do
    context 'when there is only one rabbitmq-server instance' do
      it 'contains only that single instance in cluster' do
        expect(rendered_template).to include("ERL_INETRC_HOSTS='{host, {1,1,1,1}, [\"e086aa137fa19f67d27b39d0eca18610\"]}.\n'")
      end
    end

    context 'when there are multiple rabbitmq-server instances' do
      before do
        link_instances.concat([
                                Bosh::Template::Test::InstanceSpec.new(address: '1.1.1.2'),
                                Bosh::Template::Test::InstanceSpec.new(address: '1.1.1.3')
                              ])
      end
      it 'contains all nodes in cluster' do
        expect(rendered_template).to include("ERL_INETRC_HOSTS='{host, {1,1,1,2}, [\"98660805cdee362a748327ad6032805b\"]}.")
        expect(rendered_template).to include("\n{host, {1,1,1,3}, [\"82e630489bbfe8340627fb3fdad6134c\"]}.\n'")
      end
    end
  end


  describe 'ERLANG_COOKIE' do
    context 'when rabbitmq-server.cookie is set' do
      it 'sets ERLANG_COOKIE to provided value' do
        manifest['rabbitmq-server']['cookie'] = 'example-cookie'

        expect(rendered_template).to include("export ERLANG_COOKIE=\"example-cookie\"")
      end
    end

    context 'when rabbitmq-server.cookie is not set' do
      it 'defaults to MD5 of IPs' do
        expect(rendered_template).to include("export ERLANG_COOKIE=\"e086aa137fa19f67d27b39d0eca18610\"")
      end
    end
  end

  describe 'inter node TLS' do
    context('when TLS is disabled') do
      before do
        manifest['rabbitmq-server']['ssl'] = {
          'enabled' => false,
          'inter_node_enabled' => true
        }
      end

      it 'sets INTER_NODE_TLS to true' do
        expect(rendered_template).to include('export INTER_NODE_TLS=true')
      end
    end

    context('when TLS is enabled') do
      before do
        manifest['rabbitmq-server']['ssl'] = {
          'enabled' => true,
          'inter_node_enabled' => true
        }
      end

      it 'sets INTER_NODE_TLS to true' do
        expect(rendered_template).to include('export INTER_NODE_TLS=true')
      end
    end
  end

  describe 'create_swap_delete' do
    context('is true') do
      before do
        manifest['rabbitmq-server']['create_swap_delete'] = true
        link_instances.concat([
                                Bosh::Template::Test::InstanceSpec.new(address: 'instance-1.example.bosh'),
                                Bosh::Template::Test::InstanceSpec.new(address: 'instance-2.example.bosh')
                              ])
      end

      it 'sets USE_LONGNAME to true' do
        expect(rendered_template).to include('export USE_LONGNAME=true')
      end

      it 'sets ERL_INETRC_HOSTS to an empty string' do
        expect(rendered_template).to include("export ERL_INETRC_HOSTS=''\n")
      end

      it 'sets SELF_NODE to contain FQDN' do
        expect(rendered_template).to include("export SELF_NODE=\"rabbit@instance-1.example.bosh\"\n")
      end

      it 'sets RABBITMQ_NODES_STRING to contain FQDNs' do
        expect(rendered_template).to include(
          "export RABBITMQ_NODES_STRING=\"'rabbit@instance-1.example.bosh','rabbit@instance-2.example.bosh'\"\n")
      end

      it 'defaults ERLANG_COOKIE to MD5 of addresses' do
        expect(rendered_template).to include("export ERLANG_COOKIE=\"86a3b1c813e31bcbe774b6ffa4457ac7\"")
      end
    end

    context('is not set') do
      before do
        link_instances.concat([
                                Bosh::Template::Test::InstanceSpec.new(address: '1.1.1.2'),
                                Bosh::Template::Test::InstanceSpec.new(address: '1.1.1.3')
                              ])
      end

      it 'defaults USE_LONGNAME to false' do
        expect(rendered_template).to include('export USE_LONGNAME=false')
      end

      it 'sets RABBITMQ_NODES_STRING to contain MD5 of IP addresses' do
        expect(rendered_template).to include(
          "export RABBITMQ_NODES_STRING=\"rabbit@98660805cdee362a748327ad6032805b,rabbit@82e630489bbfe8340627fb3fdad6134c\"\n")
      end
    end

    context('is set to anything other than true') do
      before do
        manifest['rabbitmq-server']['create_swap_delete'] = 'foo'
      end

      it 'defaults USE_LONGNAME to false' do
        expect(rendered_template).to include('export USE_LONGNAME=false')
      end

      it 'sets SELF_NODE to contain MD5 of IP address' do
        expect(rendered_template).to include("export SELF_NODE=\"rabbit@e086aa137fa19f67d27b39d0eca18610\"\n")
      end
    end
  end
end

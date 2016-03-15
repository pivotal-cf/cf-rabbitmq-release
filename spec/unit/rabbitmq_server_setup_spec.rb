require 'spec_helper'
require 'bosh/template/renderer'

RSpec.describe 'TLS Versions' do
  let(:manifest){ YAML.load_file('manifests/cf-rabbitmq-lite.yml')}

  before :each do
    manifest[:networks] = { blah: { ip: '127.0.0.1', default: true }}
    manifest[:job] = {name: 'rabbitmq'}
  end

  context "tls" do
    it "should have tls 1 enabled by default" do
      renderer = Bosh::Template::Renderer.new({context: manifest.to_json})

      rendered_template = renderer.render('jobs/rabbitmq-server/templates/setup.sh.erb')

      expect(rendered_template).to include(ssl_options_with "['tlsv1.2','tlsv1.1',tlsv1]")
    end

    it "should disable tls 1 when empty security specified" do
      manifest['properties']['rabbitmq-server']['ssl']['security_options'] = []
      renderer = Bosh::Template::Renderer.new({context: manifest.to_json})

      rendered_template = renderer.render('jobs/rabbitmq-server/templates/setup.sh.erb')

      expect(rendered_template).to include(ssl_options_with "['tlsv1.2','tlsv1.1']")
    end
  end

  context "nodes" do
    it "should contain all nodes in cluster" do
      renderer = Bosh::Template::Renderer.new({context: manifest.to_json})

      rendered_template = renderer.render('jobs/rabbitmq-server/templates/setup.sh.erb')

      expect(rendered_template).to include('HOSTS="${HOSTS}{host, {10,244,9,6}, [\"da3be74c053640fe92c6a39e2d7a5e46\"]}.\n"')
      expect(rendered_template).to include('HOSTS="${HOSTS}{host, {10,244,9,10}, [\"1bfd6e8e2eacf0a5ed6405a6db279bc1\"]}.\n"')
    end
  end
end

def ssl_options_with tls_versions
  'SSL_OPTIONS=" -rabbit ssl_options [{cacertfile,\\\\\"${SCRIPT_DIR}/../etc/cacert.pem\\\\\"},{certfile,\\\\\"${SCRIPT_DIR}/../etc/cert.pem\\\\\"},{keyfile,\\\\\"${SCRIPT_DIR}/../etc/key.pem\\\\\"},{verify,verify_none},{fail_if_no_peer_cert,false},{versions,' + tls_versions + '}]"'
end


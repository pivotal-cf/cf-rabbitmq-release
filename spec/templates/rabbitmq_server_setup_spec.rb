require 'spec_helper'
require 'bosh/template/renderer'

describe 'TLS Versions' do
  let(:manifest){ YAML.load_file('manifests/cf-rabbitmq-lite.yml')}

  before :each do
    networks = double("networks")
    allow(networks).to receive(:marshal_dump).and_return({"blah" => OpenStruct.new(default: true, ip: "127.0.0.1")})
    allow(networks).to receive(:methods).and_return(["mynetwork"])
    allow(networks).to receive(:mynetwork).and_return(double("ip", ip: "127.0.0.1"))
    allow_any_instance_of(OpenStruct).to receive(:networks).and_return(networks)

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
      expect(rendered_template).to include('HOSTS="${HOSTS}{host, {10,244,9,18}, [\"21b6557b73f343201277dbf290ae8b79\"]}.\n"')
    end
  end
end

def ssl_options_with tls_versions
  'SSL_OPTIONS=" -rabbit ssl_options [{cacertfile,\\\\\"${SCRIPT_DIR}/../etc/cacert.pem\\\\\"},{certfile,\\\\\"${SCRIPT_DIR}/../etc/cert.pem\\\\\"},{keyfile,\\\\\"${SCRIPT_DIR}/../etc/key.pem\\\\\"},{verify,verify_none},{fail_if_no_peer_cert,false},{versions,' + tls_versions + '}]"'
end


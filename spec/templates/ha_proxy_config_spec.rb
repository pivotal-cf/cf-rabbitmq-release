require 'spec_helper'
require 'bosh/template/renderer'

describe 'Cluster' do
  let(:manifest){ YAML.load_file('manifests/cf-rabbitmq-lite.yml')}

  it "should contain all rabbit nodes to load balance" do
    renderer = Bosh::Template::Renderer.new({context: manifest.to_json})

    rendered_template = renderer.render('jobs/rabbitmq-haproxy/templates/haproxy.config.erb')

    [5672, 5671, 1883, 8883, 61613, 61614, 15672, 15674].each do |port|
      expect(rendered_template).to include("server node0 10.244.9.6:#{port} check inter 5000")
      expect(rendered_template).to include("server node1 10.244.9.10:#{port} check inter 5000")
    end
  end
end

require 'spec_helper'

RSpec.describe 'Cluster', template: true do
  let(:rendered_template) do
    properties = {}
    links = {
      'rabbitmq-server' => {
        'instances' => [
          { "address" => '1.1.1.1' },
          { "address" => '2.2.2.2' }
        ],
        'properties' => {
          'rabbitmq-server' => {
            'ports' => [ 123, 456, 789, 10000000 ]
          }
        }
      }
    }

    compiled_template('rabbitmq-haproxy', 'haproxy.config', properties, links)
  end

  it "should contain all rabbit nodes to load balance" do
    [123, 456, 789].each do |port|
      expect(rendered_template).to include("server node0 1.1.1.1:#{port} check inter 5000")
      expect(rendered_template).to include("server node1 2.2.2.2:#{port} check inter 5000")
    end
  end

  it 'does not include too big ports' do
    expect(rendered_template).not_to include("server node0 1.1.1.1:10000000 check inter 5000")
    expect(rendered_template).not_to include("server node1 2.2.2.2:10000000 check inter 5000")
  end
end

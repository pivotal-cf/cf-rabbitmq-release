require 'spec_helper'
require 'bosh/template/renderer'
require 'bosh/template/test'

RSpec.describe 'Configuration', template: true do
  let(:rendered_template) do
    links = {
      'rabbitmq-server' => {
        'instances' => [
          { "address" => '1.1.1.1' },
          { "address" => '2.2.2.2' }
        ],
        'properties' => {
          'rabbitmq-server' => {
            'ports' => [ 123, 456, 789, 10000000 ],
            'timeouts' => [[123, "30s"]]
          }
        }
      }
    }

    compiled_template('rabbitmq-server', 'config-files/10-clusterDefaults.conf', manifest_properties, links)
  end

  context 'when there is no config provided' do
		let(:manifest_properties) { {
				'rabbitmq-server' => {}
      }
    }
    it 'renders cluster default configuration' do
      expect(rendered_template).to include('log.connection.level = info')
      expect(rendered_template).to include('cluster_partition_handling = pause_minority')
      expect(rendered_template).to include('mqtt.subscription_ttl = 1800000')
      expect(rendered_template).to include('disk_free_limit.relative = 0.4')
      expect(rendered_template).to include('cluster_formation.classic_config.nodes.1 = rabbit@e086aa137fa19f67d27b39d0eca18610')
      expect(rendered_template).to include('cluster_formation.classic_config.nodes.2 = rabbit@5b8656aafcb40bb58caf1d17ef8506a9')
    end
  end

  context 'when a partiion strategy is provided' do
		let(:manifest_properties) { {
				'rabbitmq-server' => {
          'cluster_partition_handling': 'autoheal'
        }
      } 
    }
    it 'renders cluster default configuration' do
      expect(rendered_template).to include('cluster_partition_handling = autoheal')
    end
  end

  context 'disk alarm thresholds' do
    context 'when provided a relative threshold' do
      let(:manifest_properties) { {
          'rabbitmq-server' => {
            'disk_alarm_threshold': '{mem_relative,1.5}'
          }
        } 
      }
      it 'sets a relative disk alarm' do
        expect(rendered_template).to include('disk_free_limit.relative = 1.5')
        expect(rendered_template).not_to include('disk_free_limit.absolute')
      end
    end

    context 'when provided an absolute threshold' do
      context 'when the threshold is just a number' do
        let(:manifest_properties) { {
            'rabbitmq-server' => {
              'disk_alarm_threshold': '1000000000'
            }
          } 
        }
        it 'sets an absolute disk alarm' do
          expect(rendered_template).to include('disk_free_limit.absolute = 1000000000')
          expect(rendered_template).not_to include('disk_free_limit.relative')
        end
      end
      context 'when the threshold is with units included' do
        let(:manifest_properties) { {
            'rabbitmq-server' => {
              'disk_alarm_threshold': '23GB'
            }
          } 
        }
        it 'sets an absolute disk alarm' do
          expect(rendered_template).to include('disk_free_limit.absolute = 23GB')
          expect(rendered_template).not_to include('disk_free_limit.relative')
        end
      end
    end
  end

  context 'when a cluster name is provided' do
		let(:manifest_properties) { {
				'rabbitmq-server' => {
          'cluster_name': 'my-favourite-rabbit'
        }
      }
    }
    it 'configures the cluster name' do
      expect(rendered_template).to include('cluster_name = my-favourite-rabbit')
    end
  end

  context 'when definitions are provided to the rabbitmq-server job' do
		let(:manifest_properties) { {
				'rabbitmq-server' => {
          'load_definitions': '{"hello":"world","my_name_is":73}'
        }
      } 
    }
    it 'configures RabbitMQ to import the definitions' do
      expect(rendered_template).to include('load_definitions = /var/vcap/jobs/rabbitmq-server/etc/definitions.json')

    end
  end

  context 'when the BOSH release is set to perform hot swap' do
  let(:rendered_template) do
    links = {
      'rabbitmq-server' => {
        'instances' => [
          { "address" => 'rabbit1.foo.com' },
          { "address" => 'rabbit2.foo.com' }
        ],
        'properties' => {
          'rabbitmq-server' => {
            'ports' => [ 123, 456, 789, 10000000 ],
            'timeouts' => [[123, "30s"]]
          }
        }
      }
    }

    compiled_template('rabbitmq-server', 'config-files/10-clusterDefaults.conf', manifest_properties, links)
  end
		let(:manifest_properties) { {
				'rabbitmq-server' => {
          'create_swap_delete': true
        }
      } 
    }
    it 'sets the cluster node configuration with the FQDN of the nodes' do
      expect(rendered_template).to include('cluster_formation.classic_config.nodes.1 = rabbit@rabbit1.foo.com')
      expect(rendered_template).to include('cluster_formation.classic_config.nodes.2 = rabbit@rabbit2.foo.com')
    end
  end

end

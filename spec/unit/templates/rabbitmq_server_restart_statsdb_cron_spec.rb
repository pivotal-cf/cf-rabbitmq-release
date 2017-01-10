require 'yaml'
require_relative '../../support/template_helpers.rb'

RSpec.configure do |config|
	config.include TemplateHelpers
end

RSpec.describe 'rabbitmq-server restart statsdb cron', template: true do
	context 'when we configure restart_statsdb_cron_schedule in our manifest' do
		let(:compiled_script) do
			compiled_template('rabbitmq-server', 'ensure-rabbitmq-statsdb-restart-cron',{
				'rabbitmq-server' => {
					'restart_statsdb_cron_schedule' => '* * * * *'
				}
			})
		end

		it 'should render a file which will write a cron to run the rabbitmq command which restarts statsdb on that node' do
			expect(compiled_script).to include('rabbitmqctl eval "supervisor2:terminate_child(rabbit_mgmt_sup_sup, rabbit_mgmt_sup),rabbit_mgmt_sup_sup:start_child().')
		end
	end

	context 'when we have an empty string as restart_statsdb_cron_schedule in our manifest' do
		let(:compiled_script) do
			compiled_template('rabbitmq-server', 'ensure-rabbitmq-statsdb-restart-cron',{
				'rabbitmq-server' => {
					'restart_statsdb_cron_schedule' => ''
				}
			})
		end

		it 'should render a file which will write an empty cron file' do
			expect(compiled_script).to_not include('rabbitmqctl eval "supervisor2:terminate_child(rabbit_mgmt_sup_sup, rabbit_mgmt_sup),rabbit_mgmt_sup_sup:start_child().')
		end
	end

	context 'when we do not include restart_statsdb_cron_schedule in our manifest' do
		let(:compiled_script) do
			compiled_template('rabbitmq-server', 'ensure-rabbitmq-statsdb-restart-cron')
		end

		it 'should render a file which will write an empty cron file' do
			expect(compiled_script).to_not include('rabbitmqctl eval "supervisor2:terminate_child(rabbit_mgmt_sup_sup, rabbit_mgmt_sup),rabbit_mgmt_sup_sup:start_child().')
		end
	end
end

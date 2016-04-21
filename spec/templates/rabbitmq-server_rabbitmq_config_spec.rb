
RSpec.describe 'rabbit.config file generation', template: true do
	let(:output) do
		compiled_template('rabbitmq-server', 'rabbitmq.config', {'rabbitmq-server' => { 'config' => config}}).strip
	end

	context 'when base64 encoded rabbitmq-server.rabbit.config is provided' do
		let(:config) {  nil }
		context 'statistics emission' do

			it 'sets the correct default interval' do
				expect(output).to include '{rabbit, [ {collect_statistics_interval, 60000}] }'
			end

			it 'sets the correct default management rate mode' do
				expect(output).to include '{rabbitmq_management, [ {rates_mode, none}] }'
			end
		end
	end

	context 'when base64 encoded rabbitmq-server.rabbit.config is provided' do
		let(:config) { [ 'custom_config' ].pack('m0') }

		it 'uses provided config' do
			expect(output).to eq 'custom_config'
		end
	end
end



RSpec.describe 'rabbit.config file generation', template: true do
	let(:output) do
		compiled_template('rabbitmq-server', 'rabbitmq.config', { 'rabbitmq-server' => { 'config' => config } }).strip
	end

	context 'when base64 encoded rabbitmq-server.rabbit.config is not provided' do
		let(:config) { nil }

		it 'should be empty' do
			expect(output).to be_empty
		end
	end

	context 'when base64 encoded rabbitmq-server.rabbit.config is provided' do
		let(:config) {[ 'custom_config' ].pack('m0') }

		it 'uses provided config' do
			expect(output).to eq 'custom_config'
		end
	end
end


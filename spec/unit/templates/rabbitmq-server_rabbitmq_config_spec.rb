RSpec.describe 'rabbit.config file generation', template: true do
	let(:output) do
		compiled_template('rabbitmq-server', 'rabbitmq.config', manifest_properties).strip
	end

	context 'when base64 encoded rabbitmq-server.rabbit.config is not provided' do
		let(:manifest_properties) { {} }

		it 'defaults to []. valid erlang config' do
			expect(output).to eq("[].")
		end
	end

	context 'when base64 encoded rabbitmq-server.rabbit.config is provided' do
		let(:manifest_properties) { {
				'rabbitmq-server' => {
				'config' => [ 'custom_config' ].pack('m0')
		}	} }

		it 'uses provided config' do
			expect(output).to eq 'custom_config'
		end
	end
end


RSpec.describe 'broker registration errand template', template: true do
	let(:output) {
		compiled_template('broker-registrar', 'errand.sh', manifest_properties)
	}

	context 'when ssl validation is not skipped' do
		let(:manifest_properties) do
			{'cf' => { 'skip_ssl_validation' => false }}
		end

		it 'skips ssl validation' do
			expect(output).not_to include '--skip-ssl-validation'
			expect(output).to include 'cf api'
		end
	end

	context 'when ssl validation is skipped' do
		let(:manifest_properties) do
			{'cf' => { 'skip_ssl_validation' => true }}
		end

		it 'skips ssl validation' do
			expect(output).to include 'cf api --skip-ssl-validation'
		end
	end
end


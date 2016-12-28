RSpec.describe 'broker registration errand template', template: true do
	let(:output) {
		compiled_template('broker-registrar', 'errand.sh', manifest_properties)
	}

	context 'when the manifest says to perform ssl validation' do
		let(:manifest_properties) do
			{'cf' => { 'skip_ssl_validation' => false }}
		end

		it 'performs ssl validation in errand.sh' do
			expect(output).not_to include '--skip-ssl-validation'
			expect(output).to include 'cf api'
		end
	end

	context 'when the manifest says to skip ssl validation' do
		let(:manifest_properties) do
			{'cf' => { 'skip_ssl_validation' => true }}
		end

		it 'skips ssl validation in errand.sh' do
			expect(output).to include 'cf api --skip-ssl-validation'
		end
	end
end


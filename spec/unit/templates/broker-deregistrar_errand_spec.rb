RSpec.describe 'broker deregistration errand template', template: true do
	let(:output) {
		compiled_template('broker-deregistrar', 'errand.sh', @manifest_properties)
	}

	before(:each) do
		@manifest_properties = {
			'cf' => { 'skip_ssl_validation' => false },
			'broker' => {
				'name' => 'broker_name',
				'service' => { 'name' => "service_name" }
			}
		}
	end

	it 'skips ssl validation' do
		expect(output).not_to include '--skip-ssl-validation'
		expect(output).to include 'cf api'
	end

	it 'purges the correct service offering' do
		expect(output).to include "cf purge-service-offering -f 'service_name'"
	end

	it 'deletes the correct broker' do
		expect(output).to include "cf delete-service-broker -f 'broker_name'"
	end

	context 'when ssl validation is skipped' do
		before(:each) do
			@manifest_properties['cf']['skip_ssl_validation'] = true
		end

		it 'skips ssl validation' do
			expect(output).to include 'cf api --skip-ssl-validation'
		end
	end

	context 'when I set my broker service name' do
		before(:each) do
			@manifest_properties['broker']['service']['name'] = "broker_service_name"
		end

		it 'purges the correct service offering' do
			expect(output).to include "cf purge-service-offering -f 'broker_service_name'"
		end
	end

	context 'when I set my broker name' do
		before(:each) do
			@manifest_properties['broker']['name'] = "changed_broker_name"
		end

		it 'deletes the correct broker' do
			expect(output).to include "cf delete-service-broker -f 'changed_broker_name'"
		end
	end
end


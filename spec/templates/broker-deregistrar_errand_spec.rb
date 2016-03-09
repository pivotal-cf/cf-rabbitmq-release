require 'bosh/template/renderer'
require 'yaml'

RSpec.describe 'broker deregistration errand template' do
	let(:renderer) {
		Bosh::Template::Renderer.new({context: manifest.to_json})
	}

	let(:output) { renderer.render('jobs/broker-deregistrar/templates/errand.sh.erb') }

	context 'when ssl validation is not skipped' do
		let(:manifest){ emulate_bosh_director_merge ({'cf' => { 'skip-ssl-validation' => false }}) }

		it 'skips ssl validation' do
			expect(output).not_to include '--skip-ssl-validation'
			expect(output).to include 'cf api'
		end
	end

	context 'when ssl validation is skipped' do
		let(:manifest){ emulate_bosh_director_merge ({'cf' => {'skip-ssl-validation' => true }}) }

		it 'skips ssl validation' do
			expect(output).to include 'cf api --skip-ssl-validation'
		end
	end
end


include Bosh::Template::PropertyHelper

# Trying to emulate bosh director Bosh::Director::DeploymentPlan::Job#extract_template_properties
def emulate_bosh_director_merge(manifest_properties)
	job_spec = YAML.load_file('jobs/broker-deregistrar/spec')
	spec_properties = job_spec["properties"]

	effective_properties = {}
	spec_properties.each_pair do |name, definition|
		copy_property(effective_properties, manifest_properties, name, definition["default"] || '')
	end

	{"properties" => effective_properties}
end

require 'spec_helper'
require 'bosh/template/test'

RSpec.describe 'rabbitmq-server' do
  let(:release) { Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '../../..')) }
  let(:job) { release.job('rabbitmq-server') }

  describe 'setup-vars.bash.erb' do
    let(:template) { job.template('lib/setup-vars.bash') }

    it 'contains deployment name', :focus => true do
      spec = Bosh::Template::Test::InstanceSpec.new
      output = template.render(spec: spec)

      p spec
      p template
      expect(output).to include "xxxxx" 
    end
  end
end

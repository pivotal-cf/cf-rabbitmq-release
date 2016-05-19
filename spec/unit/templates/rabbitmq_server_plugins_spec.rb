require 'spec_helper'
require 'tempfile'

RSpec.describe 'Enabling plugins', template: true do
	let(:metadata) { {'rabbitmq-server' => { 'plugins' => ['good_plugin', 'bad_plugin']}} }
	let(:rabbitmq_plugins_ctl) { 'spec/unit/templates/assets/rabbitmq-plugins-stub.sh' }

  let(:command_output) do
		template = compiled_template('rabbitmq-server', 'plugins.sh', metadata)

    Tempfile.open('plugins') do |command_file|
      command_file.write(template)
      command_file.close

      return `RABBITMQ_PLUGINS="#{rabbitmq_plugins_ctl}" STUBBED_PLUGINS_LIST="#{plugins_list}" bash #{command_file.path}`
    end
  end

  let(:plugins_list) { %{good_plugin\nunused_plugin} }

  context "when the specified plugin is missing on server" do
    it "does not enable the specified plugin" do
      expect(command_output).not_to include('Test enable: bad_plugin')
    end

    it 'shows warning about missing plugin' do
      expect(command_output).to include('Ignoring unrecognised plugin: bad_plugin')
    end
  end

  context "when the specified plugin is enabled but missing on server" do
    let(:plugins_list) do
      %{
WARNING - plugins currently enabled but missing: [bad plugin]

good_plugin
unused_plugin
      }
    end

    it "does not enable the specified plugin" do
      expect(command_output).not_to include('Test enable: bad_plugin')
    end

    it 'shows warning about missing plugin' do
      expect(command_output).to include('Ignoring unrecognised plugin: bad_plugin')
    end
  end

  it 'enables plugin' do
    expect(command_output).not_to include('Test enable: good_plugin')
  end
end

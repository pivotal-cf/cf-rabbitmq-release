require 'spec_helper'
require 'bosh/template/renderer'
require 'tempfile'

RSpec.describe 'Enabling plugins' do
  let(:manifest){ YAML.load_file('spec/support/manifest/test.yml')}

  context "when there is a plugin specified in the manifest but missing on server" do
    it "should not enable the specified plugin, but give a warning" do
      plugins_list=%{rabbitmq_management
rabbitmq_mqtt
      }
      output = render_and_execute_template(plugins_list)
      expect(output).to eq("Ignoring unrecognised plugin: rabbitmq_stomp\n")
    end
  end

  context "when there is a plugin specified in the manifest but missing on server and is displayed as a warning" do
    it "should not enable the specified plugin, but give a warning" do
      plugins_list=%{
WARNING - plugins currently enabled but missing: [rabbitmq_stomp]

rabbitmq_management
rabbitmq_mqtt
      }

      output = render_and_execute_template(plugins_list)
      expect(output).to eq("Ignoring unrecognised plugin: rabbitmq_stomp\n")
    end
  end


  context "when there is a plugin specified in the manifest and present on the server" do
    it "should enable the specified plugin, but not give a warning" do
      plugins_list=%{rabbitmq_management
rabbitmq_mqtt
rabbitmq_stomp
      }

      output = render_and_execute_template(plugins_list)
      expect(output).to be_empty
    end
  end
end


def render_and_execute_template(plugins_list)
  renderer = Bosh::Template::Renderer.new({context: manifest.to_json})
  rendered_template = renderer.render('jobs/rabbitmq-server/templates/plugins.sh.erb')

  command_file = Tempfile.new('plugins')
  command_file.write(rendered_template)
  command_file.close
  File.chmod(0744, command_file.path)

  output = `RABBITMQ_PLUGINS=spec/templates/rabbitmq-plugins-stub.sh STUBBED_PLUGINS_LIST="#{plugins_list}" #{command_file.path}`
  command_file.unlink
  output
end

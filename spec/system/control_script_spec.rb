require 'yaml'
require 'bosh/template/renderer'
require 'tempfile'
require 'fileutils'

describe 'timeout helper' do
  let(:manifest) { YAML.load_file('manifests/cf-cassandra-aws-eu.yml')}
  let(:renderer) { Bosh::Template::Renderer.new({context: manifest.to_json})}
  let(:rendered_template_file) {
    rendered_template = renderer.render('jobs/cassandra_node/templates/bin/helpers/timeout.erb')

    rendered_template_file = Tempfile.new('rendered_template')
    rendered_template_file.write(rendered_template)
    rendered_template_file.close

    return rendered_template_file
  }

  it 'runs our basht tests' do
    puts `basht #{rendered_template_file.path}`
    expect($?.exitstatus).to eq(0)
  end
end

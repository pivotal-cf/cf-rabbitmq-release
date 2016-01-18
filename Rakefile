RELEASE_FOLDER = "./"

desc 'run all the specs'
task spec: %w(spec:unit spec:system)

namespace :spec do
  require 'rspec/core/rake_task'

  desc 'run all of the system tests'
  RSpec::Core::RakeTask.new(:system) do |t|
    t.pattern = FileList['spec/system/**/*_spec.rb']
  end

  desc 'run all of the unit tests'
  RSpec::Core::RakeTask.new(:unit) do |t|
    t.pattern = FileList['spec/unit/**/*_spec.rb']
  end
end

task default: :spec

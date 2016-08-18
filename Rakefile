RELEASE_FOLDER = "./"

desc 'run all the specs'
task spec: %w(spec:unit spec:system)

desc 'Installs noaa'
task :install_noaa do
  `go get github.com/cloudfoundry/noaa/samples/firehose`
end

namespace :spec do
  require 'rspec/core/rake_task'

  task :system => :install_noaa

  desc 'run all of the system tests'
  RSpec::Core::RakeTask.new(:system) do |t|
    t.pattern = FileList['spec/system/**/*_spec.rb']
  end

  desc 'run all of the unit tests'
  RSpec::Core::RakeTask.new(:rspec_unit) do |t|
    t.pattern = FileList['spec/unit/**/*_spec.rb']
  end

  desc 'runs basht unit tests'
  task :bash_unit do
    cmd = './scripts/run-basht-tests'
    system("bash -c #{cmd.shellescape}")
    status = $?
    if status != 0
      raise "'#{cmd}' execution failed (exit code: #{status}"
    end
  end

  task :unit => [:bash_unit, :rspec_unit]
end

task default: :spec

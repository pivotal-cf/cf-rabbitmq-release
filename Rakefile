require 'yaml'

RELEASE_FOLDER = "./"

load 'pipeline/release/tasks/build_final.rake'
load 'pipeline/release/tasks/audit.rake'
load 'pipeline/release/tasks/deploy.rake'
load 'pipeline/release/tasks/update_release.rake'

namespace :ci do
  load 'continuous_configuration/rake_tasks/configure.rake'
  load 'continuous_configuration/rake_tasks/dump.rake'
  load 'continuous_configuration/rake_tasks/diff.rake'
end

def deployment_exists?(manifest)
  exists?('deployments', deployment_name(manifest))
end

def release_exists?
  exists?('releases', 'bosh-release')
end

def exists?(type, name)
  result = %x{bosh -n #{type}}
  raise "Unable to list #{type}" unless $?.success?
  result.split("\n").any? do |line|
    line.include?(" #{name} ")
  end
end

def deployment_name(file)
  YAML::load_file(file)['name']
end

desc 'Create the RabbitMQ BOSH release'
task :create_release do
  Dir.chdir(RELEASE_FOLDER)
  sh 'bosh -n create release --force --name cf-rabbitmq-os'
end

desc 'Upload the release to the BOSH director'
task :upload_release, [:manifest,:director_url,:username,:password] => :create_release do |_, args|
  args.with_defaults(:username => 'admin', :password => 'admin')
  Dir.chdir(RELEASE_FOLDER)

  sh "bosh -n target #{args[:director_url]}"
  sh "bosh -n login #{args[:username]} #{args[:password]}"

  if deployment_exists?(args[:manifest])
    sh "bosh -n delete deployment #{deployment_name(args[:manifest])}"
  end
  if release_exists?
    sh 'bosh -n delete release bosh-release'
  end

  sh 'bundle exec bosh -n upload release'
end

desc 'deploy this release to bosh'
task :deploy, [
  :bosh_manifest,
  :bosh_username,
  :bosh_password,
  :bosh_target
]do |_, args|
  Dir.chdir(RELEASE_FOLDER)
  sh "bosh -n target #{args[:bosh_target]}"
  sh "bosh -n login #{args[:bosh_username]} #{args[:bosh_password]}"
  sh "bosh -n create release --force --name cf-rabbitmq-os"
  sh "bosh -n upload release --rebase"
  sh "bosh -n --deployment #{args[:bosh_manifest]} deploy"
end

namespace :release_pipeline do
  desc 'upload a bosh release'
  task :upload, [
    :release_glob,
    :aws_access_key_id,
    :aws_secret_access_key
  ] do |_, args|
    require 'pipeline/upload'
    config = {
      file_path: Dir.glob(args[:release_glob]).first,
      aws_access_key_id: args[:aws_access_key_id],
      aws_secret_access_key: args[:aws_secret_access_key],
      bucket_name: 'cf-services-internal-builds',
      bucket_path: 'rabbitmq'
    }
    Pipeline::Upload.new(config).run
  end

  desc 'Builds the final release and updates both repos'
  task :build_final_release_in_submodule, [
    :aws_access_key_id,
    :aws_secret_access_key,
    :build_number] => [:change_to_release_folder, :build_final]

  desc 'Builds the final release in the submodule repository'
  task :change_to_release_folder do
    Dir.chdir(RELEASE_FOLDER)
  end
end

desc 'run all the specs'
task spec: %w(spec:templates spec:system)

namespace :spec do
  require 'rspec/core/rake_task'

  desc 'run all of the system tests'
  RSpec::Core::RakeTask.new(:system) do |t|
    t.pattern = FileList['spec/system/**/*_spec.rb']
  end

  desc 'run all of the template tests'
  RSpec::Core::RakeTask.new(:templates) do |t|
    t.pattern = FileList['spec/templates/**/*_spec.rb']
  end
end

task default: :spec

require 'spec_helper'
require 'rubygems/package'
require 'zlib'
require 'yaml'
require 'httparty'

def list_blobs
  blobs = YAML.load_file('config/blobs.yml')
  blobs.select { |key| key.match('(erlang-\d+\/otp)') }.keys
end

RSpec.describe 'OSS Compliance', run_compliance_tests: true do
  list_blobs.each do |version|

    describe "Erlang blob compliance #{version}" do
      before :all do
        @blob_path = fetch_blob(version)
      end

      it 'should not contain proper/proper_common.hrl' do
        expect(blob_contains(@blob_path, "proper\/proper_common.hrl")).to be(false)
      end

      it 'should not contain ewgi/ewgi.hrl' do
        expect(blob_contains(@blob_path, "ewgi\/ewgi.hrl")).to be(false)
      end

      it 'should not contain ewgi2/ewgi.hrl' do
        expect(blob_contains(@blob_path, "ewgi2\/ewgi.hrl")).to be(false)
      end
    end
  end
end

def download_from_blob_bucket(blob_object_id, local_destination)
  bucket_address ="https://pcf-rabbitmq-bosh-release-blobs.s3.amazonaws.com"
  File.open("#{local_destination}", "wb") do |f|
      f.write HTTParty.get("#{bucket_address}/#{blob_object_id}").parsed_response
  end
end

def fetch_blob(blob_prefix)
  blobs = YAML.load_file('config/blobs.yml')
  blob_properties = blobs.detect{ |key,val| /#{blob_prefix}/.match(key) }[1]

  local_destination = "/tmp/erlang_oss_test_run.tgz"
  download_from_blob_bucket(blob_properties["object_id"], local_destination)

  local_destination
end

def blob_contains(blob_path, filename)
  tar_extract = Gem::Package::TarReader.new(Zlib::GzipReader.open(blob_path))
  tar_extract.rewind # The extract has to be rewinded after every iteration
  tar_extract.count { |entry| /#{filename}/.match(entry.full_name) } != 0
end

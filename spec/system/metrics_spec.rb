require 'spec_helper'

describe 'metrics', :skip_metrics => true do

  before(:all) do
    @number_of_nodes = 1
    @outFile = Tempfile.new('smetrics')
    @pid = spawn(
      {
        'DOPPLER_ADDR' => doppler_address,
        'CF_ACCESS_TOKEN' => cf.auth_token
      },
      'firehose_sample',
      [:out, :err] => [@outFile.path, 'w']
    )
  end

  after(:all) do
    Process.kill("INT", @pid)
    @outFile.unlink
  end

  describe 'rabbitmq example metrics' do
    ["/rabbitmq/example/heartbeat"
    ].each do |metric_name|
      it "contains #{metric_name} metric for rabbitmq haproxy nodes" do
        @number_of_nodes.times do |idx|
          assert_metric(metric_name, 'haproxy_z1', idx)
        end
      end
    end
  end

  def assert_metric(metric_name, job_name, job_index)
    metric = find_metric(metric_name, job_name, job_index)

    expect(metric).to match(/value:\d/)
    expect(metric).to include('origin:"rmq"')
    expect(metric).to include('deployment:"cf-rabbitmq"')
    expect(metric).to include('eventType:ValueMetric')
    expect(metric).to match(/timestamp:\d/)
    expect(metric).to match(/index:"\d"/)
    expect(metric).to match(/ip:"\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}"/)
  end

  def find_metric(metric_name, job_name, job_index)
    31.times do
      File.open(firehose_out_file, "r") do |file|
        regex = /(?=.*name:"#{metric_name}")(?=.*job:"#{job_name}")(?=.*index:"#{job_index}")/
        matches = file.readlines.grep(regex)
        if matches.size > 0
          return matches[0]
        end
      end
      sleep 1
    end
    fail("metric '#{metric_name}' for job '#{job_name}' with index '#{job_index}' not found")
  end

  def firehose_out_file
    @outFile.path
  end
end

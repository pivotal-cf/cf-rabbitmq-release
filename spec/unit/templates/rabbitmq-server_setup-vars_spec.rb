RSpec.describe 'setup-vars.bash file generation', template: true do
  let(:tls_versions) { [] }
  let(:tls_ciphers) { [] }

  let(:manifest_properties) do
    { 'rabbitmq-server' => {
      'ssl' => {
        'versions' => tls_versions,
        'ciphers' => tls_ciphers
      }
    } }
  end

  let(:output) do
    compiled_template('rabbitmq-server', 'setup-vars.bash', manifest_properties).strip
  end

  context 'when tls versions are missing' do
    let(:manifest_properties) { {} }

    it 'uses provided tls versions' do
      expect(output).to include "SSL_SUPPORTED_TLS_VERSIONS=\"['tlsv1.2','tlsv1.1']\""
    end
  end

  context 'when tls versions are configured' do
    let(:tls_versions) { ['tlsv1.2'] }

    it 'uses provided tls versions' do
      expect(output).to include "SSL_SUPPORTED_TLS_VERSIONS=\"['tlsv1.2']\""
    end
  end

  context 'when tls is not a collection' do
    let(:tls_versions) { '' }

    it 'raises an error' do
      expect { output }.to \
        raise_error 'Expected rabbitmq-server.ssl.versions to be a collection'
    end
  end

  context 'when tls collection contain unsupported versions' do
    let(:tls_versions) { ['tlsv1', 'weird-not-supported-version'] }

    it 'raises an error' do
      expect { output }.to \
        raise_error 'weird-not-supported-version is a not supported tls version'
    end
  end

  context 'when tls ciphers are missing' do
    let(:manifest_properties) { {} }

    it 'do not configure ciphers and fallback to openssl defaults' do
      expect(output).to include 'SSL_SUPPORTED_TLS_CIPHERS=""'
    end
  end

  context 'when tls ciphers are specified' do
    let(:tls_ciphers) { %w[SOME-valid-cipher-12323 something] }

    it 'uses provided ciphers and wraps each of them with \" so they are interpretted by bash correctly' do
      expect(output).to include "SSL_SUPPORTED_TLS_CIPHERS=\",{ciphers,[\\\"SOME-valid-cipher-12323\\\",\\\"something\\\"]}\""
    end
  end

  context 'when invalid tls ciphers are specified' do
    let(:tls_ciphers) { %w[SOME-valid-cipher-12323 an_invalid_!@#$] }

    it 'raise an error' do
      expect { output }.to raise_error 'an_invalid_!@#$ is not a valid cipher suite'
    end
  end

  describe 'cluster partition handling' do
    it 'exports a variable with pause_minority by default when none is given' do
      expect(output).to include 'export CLUSTER_PARTITION_HANDLING="pause_minority"'
    end

    context 'when a different cluster partition handling is given' do
      let(:manifest_properties) do
        { 'rabbitmq-server' => {
          'cluster_partition_handling' => 'autoheal'
          }
        }
      end

      it 'exports a variable with provided cluster partition' do
        expect(output).to include 'export CLUSTER_PARTITION_HANDLING="autoheal"'
      end
    end
  end

  describe 'disk alarm threshold' do
    it 'exports a variable with default threshold when none is given' do
      expect(output).to include 'export DISK_ALARM_THRESHOLD="{mem_relative,0.4}"'
    end

    context 'when a different disk alarm threshold is given' do
      let(:manifest_properties) do
        { 'rabbitmq-server' => {
          'disk_alarm_threshold' => '{mem_relative,1.5}'
          }
        }
      end

      it 'exports a variable with provided disk alarm threshold' do
        expect(output).to include 'export DISK_ALARM_THRESHOLD="{mem_relative,1.5}"'
      end
    end
  end
end

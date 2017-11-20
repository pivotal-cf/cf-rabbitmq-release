RSpec.describe 'setup-vars.bash file generation', template: true do
  let(:output) do
    compiled_template('rabbitmq-server', 'setup-vars.bash', manifest_properties).strip
  end
  let(:manifest_properties) do
    { 'rabbitmq-server' => {
      'ssl' => {
        'versions' => tls_versions,
        'ciphers' => tls_ciphers
      }
    } }
  end
  let(:tls_versions) { [] }
  let(:tls_ciphers) { [] }

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
end

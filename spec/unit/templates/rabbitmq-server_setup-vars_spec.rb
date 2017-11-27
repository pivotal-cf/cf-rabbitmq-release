RSpec.describe 'setup-vars.bash file generation', template: true do

  let(:manifest_properties) do
    {
      'rabbitmq-server' => {
        'ssl' => { }
      }
    }
  end


  let(:output) do
    compiled_template('rabbitmq-server', 'setup-vars.bash', manifest_properties).strip
  end

  describe 'TLS configuration' do
    context 'when properties are not configured' do
      let(:manifest_properties) { {} }

      it 'uses default tls versions' do
        expect(output).to include "export SSL_SUPPORTED_TLS_VERSIONS=\"['tlsv1.2','tlsv1.1']\""
      end

      it 'should do not configure ciphers and fallback to openssl defaults' do
        expect(output).to include 'export SSL_SUPPORTED_TLS_CIPHERS=""'
      end

      it 'uses default fail_if_no_peer_cert' do
        expect(output).to include 'export SSL_FAIL_IF_NO_PEER_CERT="false"'
      end

      it 'uses default peer verification method' do
        expect(output).to include 'export SSL_VERIFY="false"'
      end

      it 'uses default ssl verification depth' do
        expect(output).to include 'export SSL_VERIFICATION_DEPTH="5"'
      end
    end

    context 'when tls versions are configured' do
      before :each do
        manifest_properties['rabbitmq-server']['ssl']['versions'] = ['tlsv1.2']
      end

      it 'uses provided tls versions' do
        expect(output).to include "export SSL_SUPPORTED_TLS_VERSIONS=\"['tlsv1.2']\""
      end
    end

    context 'when ciphers are configured' do
      before :each do
        manifest_properties['rabbitmq-server']['ssl']['ciphers'] = %w[SOME-valid-cipher-12323 something]
      end

      it 'uses provided ciphers and wraps each of them with \" so they are interpretted by bash correctly' do
        expect(output).to include "SSL_SUPPORTED_TLS_CIPHERS=\",{ciphers,[\\\"SOME-valid-cipher-12323\\\",\\\"something\\\"]}\""
      end
    end

    context 'when verification_depth is configured' do
      before :each do
        manifest_properties['rabbitmq-server']['ssl']['verification_depth'] = 10
      end

      it 'uses provided value' do
        expect(output).to include 'export SSL_VERIFICATION_DEPTH="10"'
      end
    end

    context 'when ssl_verify is configured' do
      before :each do
        manifest_properties['rabbitmq-server']['ssl']['verify'] = true
      end

      it 'uses provided value' do
        expect(output).to include 'export SSL_VERIFY="true"'
      end
    end

    context 'when ssl fail if no peer cert is configured' do
      before :each do
        manifest_properties['rabbitmq-server']['ssl']['fail_if_no_peer_cert'] = true
      end

      it 'uses provided value' do
        expect(output).to include 'export SSL_FAIL_IF_NO_PEER_CERT="true"'
      end
    end

    context 'when tls version is invalid' do
      context 'when tls is not a collection' do
        before :each do
          manifest_properties['rabbitmq-server']['ssl']['versions'] = ''
        end

        it 'raises an error' do
          expect { output }.to \
            raise_error 'Expected rabbitmq-server.ssl.versions to be a collection'
        end
      end

      context 'when tls version is not supported' do
        before :each do
          manifest_properties['rabbitmq-server']['ssl']['versions'] =  ['tlsv1', 'weird-not-supported-version'] 
        end

        it 'raises an error' do
          expect { output }.to \
            raise_error 'weird-not-supported-version is a not supported tls version'
        end
      end
    end

    context 'when invalid tls ciphers are specified' do
      before :each do
        manifest_properties['rabbitmq-server']['ssl']['ciphers'] = %w[SOME-valid-cipher-1232 an_invalid_!@#$]
      end

      it 'raise an error' do
        expect { output }.to raise_error 'an_invalid_!@#$ is not a valid cipher suite'
      end
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

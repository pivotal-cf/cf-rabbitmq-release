RSpec.describe 'broker-registrar errand template', template: true do
  let(:output) {
    compiled_template('broker-registrar', 'errand.sh', manifest_properties)
  }

  context 'when the manifest says to perform ssl validation' do
    let(:manifest_properties) do
      {'cf' => { 'skip_ssl_validation' => false }}
    end

    it 'performs ssl validation in errand.sh' do
      expect(output).not_to include '--skip-ssl-validation'
      expect(output).to include 'cf api'
    end
  end

  context 'when the manifest says to skip ssl validation' do
    let(:manifest_properties) do
      {'cf' => { 'skip_ssl_validation' => true }}
    end

    it 'skips ssl validation in errand.sh' do
      expect(output).to include 'cf api --skip-ssl-validation'
    end
  end

  context 'when the orgs propery is not set' do
    let(:manifest_properties) do
      {'broker-registrar' => { 'orgs' => [] }}
    end

    it 'enables access to the service broker for all orgs' do
      expect(output).to include 'cf enable-service-access $SERVICE_NAME'
    end
  end

  context 'when the orgs property is set' do
    let(:manifest_properties) do
      {'broker-registrar' => { 'orgs' => ['org1','org2'] }}
    end

    it 'enables access to the service broker for the specified orgs only' do
      expect(output).to include 'cf enable-service-access $SERVICE_NAME -o org1'
      expect(output).to include 'cf enable-service-access $SERVICE_NAME -o org2'
    end
  end
end


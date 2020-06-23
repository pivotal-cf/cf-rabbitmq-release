RSpec.describe 'pre-stop.bash template', template: true do
  let(:output) do
    compiled_template('rabbitmq-server', 'pre-stop.bash', manifest_properties).strip
  end

  describe 'CHECK_QUEUE_SYNC' do
    context 'when rabbitmq-server.check_queue_sync is true' do
      let(:manifest_properties) do
        {
          'rabbitmq-server' => {
            'check_queue_sync' => true
          }
        }
      end

      it 'renders CHECK_QUEUE_SYNC to true' do
        expect(output).to include 'CHECK_QUEUE_SYNC=${CHECK_QUEUE_SYNC:-true}'
      end
    end

    context 'when rabbitmq-server.check_queue_sync is false' do
      let(:manifest_properties) do
        {
          'rabbitmq-server' => {
            'check_queue_sync' => false
          }
        }
      end

      it 'renders CHECK_QUEUE_SYNC to false' do
        expect(output).to include 'CHECK_QUEUE_SYNC=${CHECK_QUEUE_SYNC:-false}'
      end
    end

    context 'when rabbitmq-server.check_queue_sync is not set' do
      let(:manifest_properties) do
        { 'rabbitmq-server' => { } }
      end

      it 'defaults CHECK_QUEUE_SYNC to false' do
        expect(output).to include 'CHECK_QUEUE_SYNC=${CHECK_QUEUE_SYNC:-false}'
      end
    end
  end
end

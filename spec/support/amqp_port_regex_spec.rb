require 'support/amqp_port_regex'

RSpec.describe AMQPPortRegex, '#regex' do
  context "matching the AMQP port" do
    before(:each) do
      @amqp_tcp_regexp = AMQPPortRegex.regex
    end

    it "does not match the management port" do
      output = "Asking node for listeners\nmgmt port: 15672\nanother port 007\n"

      expect(output).not_to match(@amqp_tcp_regexp)
    end

    it "does not match the inter-node communication port" do
      output = "Asking node for listeners\nmgmt port: 25672\nanother port 007\n"

      expect(output).not_to match(@amqp_tcp_regexp)
    end

    it "matches the AMQP port" do
      output = "Asking node for listeners\namqp port 5672\nanother port 007\n"

      expect(output).to match(@amqp_tcp_regexp)
    end
  end

  context "matching the AMQP+SSL port" do
    before(:each) do
      @amqp_ssl_regexp = AMQPPortRegex.ssl_regex
    end

    it "does not match the management port" do
      output = "Asking node for listeners\nmgmt port 15671\nanother port 007\n"

      expect(output).not_to match(@amqp_ssl_regexp)
    end

    it "matches the AMQP port" do
      output = "Asking node for listeners\namqp port 5671\nanother port 007\n"

      expect(output).to match(@amqp_ssl_regexp)
    end
  end
end

class AMQPPortRegex
  class << self; attr_reader :regex, :ssl_regex end

  # do not match 15672, but match 5672
  @regex = "^[^1]*5672"

  # do not match 15671, but match 5671
  @ssl_regex = "^[^1]*5671"
end

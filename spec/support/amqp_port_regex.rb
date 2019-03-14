class AMQPPortRegex
  class << self; attr_reader :regex, :ssl_regex end

  # do not match 15672 and 25672, but match 5672
  @regex = "^[^12]*5672"

  # do not match 15671 and 25671, but match 5671
  @ssl_regex = "^[^12]*5671"
end

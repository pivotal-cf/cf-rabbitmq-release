# rabbitmq-upgrade-preparation

This is a utility which checks whether the RabbitMQ nodes in a cluster need
shutting down. For example, certain versions of RabbitMQ are incompatible and
the cluster cannot run in mixed mode. Same for different versions of Erlang. If
this utility discovers such a scenario, it will iterate over all the nodes in
the cluster and shut them down.

See [cf-rabbitmq-release](https://github.com/pivotal-cf/cf-rabbitmq-release)
for the only real use of this.

## How do I install this?

`script/setup`

## How do I run the tests?

`script/run_tests`


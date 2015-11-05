# rabbitmq-upgrade-preparation

Prepares a RabbitMQ cluster for upgrade, of either RabbitMQ itself or the Erlang runtime. Currently, all this means is that it shuts down a node before a version upgrade, as RabbitMQ clusters cannot run with mixed major/minor versions. Mixed patch versions are fine.

See [cf-rabbitmq-release](https://github.com/pivotal-cf/cf-rabbitmq-release) for the only real use of this.

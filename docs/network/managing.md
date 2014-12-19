# Deploying and Managing the RabbitMQ service

The Cloud Foundry release will install zero or one RabbitMQ
clusters of largely any size. The installation has a load balancer
(`haproxy`) which spreads connections on all of the default ports for
all of the shipped plugins across all the machines within the cluster.

There is integration with Cloud Foundry. From Cloud Foundry you can
create **instances** of RabbitMQ (which amount to **vhosts**) and then
bind apps to those **instances** (which amount to creating user
accounts with permissions to access the relevant **vhost**). The URIs
which are injected into the `VCAP_SERVICES` environment variable for
apps running on Cloud Foundry point at the IP of the load
balancer. Consquently you can change the size of your RabbitMQ cluster
from the installer, redeploy, and find the load balancer automatically
reconfigured and no need to change any details within your apps on
Cloud Foundry.


Via the installer you:

- must choose an admin username and password for RabbitMQ. This will
  grant you full admin access to RabbitMQ via the Managment UI.

- can choose which plugins you wish to enable. You *must* leave the
  Management plugin enabled otherwise nothing will work.

- can provide SSL keys and certificates for use by the RabbitMQ
  cluster. Note SSL is simultaneously provided on the amqps port
  (5671) and the management port (15672). If you provide SSL keys and
  certificates, you are disabling non-SSL support. No other plugins
  are automatically configured for use with SSL. Note SSL settings are
  applied equally across all machines in the cluster.

- can specify the Erlang cookie value. This is useful if you wish to
  use other machines running Erlang to interact directly with the
  Erlang nodes running RabbitMQ, e.g. if you wish to run `rabbitmqctl`
  from a machine that is not part of the RabbitMQ cluster.

- can provide a full
  [`rabbitmq.config`](http://www.rabbitmq.com/configure.html) file, if
  you need to. Note this file is provided to all the nodes in the
  cluster.

- can easily resize the RabbitMQ cluster without losing state.

- can change which ports are load-balanced by `haproxy`. By default
  all the default ports of all the available plugins will be
  load-balanced. However, if you install extra protocol plugins, or
  provide a custom configuration which changes the ports that RabbitMQ
  listens on then you must update the list of load-balanced
  ports. Note that you must always leave the management plugin
  listening on port 15672 and load balance that port.


## Accessing RabbitMQ Management plugin

To gain access to the Management UI as the admin user, after
installation inspect the *Status* tab within the RabbitMQ components
of the installer. This will give you the IP of the load balancer. In a
browser, go to this IP on port 15672. The username and password is the
username and password you provided in the RabbitMQ configuration,
which is also shown in the *Credentials* tab.

Users of Cloud Foundry who create instances via the Cloud Foundry web
console, or the `cf` CLI also get access to the Management UI. This is
done using credentials that provide access only to their particular
**vhost**. The appropriate URL is accessible via the *Manage* button
within the Cloud Foundry web console, but is also injected into the
`VCAP_SERVICES` environment variable provided to apps running on Cloud
Foundry.

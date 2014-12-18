# Accessing the RabbitMQ cluster directly

If you wish to run commands such as `rabbitmqctl` then you have two
options:

1. SSH into one of the machines running the **rabbitmq-server**. IPs
can be found from the Status tab and access credentials from the
Credentials tab within the RabbitMQ component of the installer. From
there you need to bring RabbitMQ and Erlang into your environment and
from there you can use `rabbitmqctl`:
      
        bash-4.1# . /var/vcap/packages/erlang/enable; . /var/vcap/packages/rabbitmq-server/enable
        bash-4.1# rabbitmqctl cluster_status
        Cluster status of node rabbit@node0 ...
        [{nodes,[{disc,[rabbit@node0,rabbit@node1,rabbit@node2,rabbit@node3]}]},
         {running_nodes,[rabbit@node3,rabbit@node2,rabbit@node1,rabbit@node0]},
         {partitions,[]}]
        ...done.

2. Alternatively install RabbitMQ and Erlang on a machine of your
choice (though be sure to match versions of both to the cluster: the
Management UI shows both the version of RabbitMQ and Erlang). Then set
your `~/.erlang.cookie` to match the cookie used in the cluster (you
may have supplied this as part of the installation; see above). The
nodes in the cluster are always named numerically from *node0*
upwards. You'll need to set up your `/etc/hosts` file so that *node0*
is the first IP of your cluster of Rabbits and so on. Then you should
find you can use `rabbitmqctl` locally.

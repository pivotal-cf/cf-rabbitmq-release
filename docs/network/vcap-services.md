# RabbitMQ entries in the `VCAP_SERVICES` environment variable

Applications running in Cloud Foundry gain access to service instances
which are bound to them by credentials passed to them through the
`VCAP_SERVICES` environment variable available to the application.
Here is an example:

    {"p-rabbitmq-3.1.5":
      [{"name": "myrabbit",
        "label": "p-rabbitmq-3.1.5",
        "tags":["rabbitmq","messaging","message-queue","amqp"],
        "plan": "standard",
        "credentials":
          {"uri": "amqp://u6e10e2df0903ecac86bc03f396c6d2b56089769b:p262615006c0001a482577e0d7a5400dca3ed40c3@10.26.152.25/5686900df5c8a9fa28668536ce0d3ddba206c3d4",
           "vhost": "5686900df5c8a9fa28668536ce0d3ddba206c3d4",
           "username": "u6e10e2df0903ecac86bc03f396c6d2b56089769b",
           "password": "p262615006c0001a482577e0d7a5400dca3ed40c3",
           "hostname": "10.26.152.25",
           "http_api_uri": "http://u6e10e2df0903ecac86bc03f396c6d2b56089769b:p262615006c0001a482577e0d7a5400dca3ed40c3@10.26.152.25:15672/api/",
           "protocols":
             {"amqp":
               {"uri": "amqp://u6e10e2df0903ecac86bc03f396c6d2b56089769b:p262615006c0001a482577e0d7a5400dca3ed40c3@10.26.152.25:5672/5686900df5c8a9fa28668536ce0d3ddba206c3d4",
                "username": "u6e10e2df0903ecac86bc03f396c6d2b56089769b",
                "password": "p262615006c0001a482577e0d7a5400dca3ed40c3",
                "port": 5672,
                "host": "10.26.152.25",
                "vhost": "5686900df5c8a9fa28668536ce0d3ddba206c3d4"},
              "management":
                {"uri": "http://u6e10e2df0903ecac86bc03f396c6d2b56089769b:p262615006c0001a482577e0d7a5400dca3ed40c3@10.26.152.25:15672/api/",
                 "username": "u6e10e2df0903ecac86bc03f396c6d2b56089769b",
                 "password": "p262615006c0001a482577e0d7a5400dca3ed40c3",
                 "port": 15672,
                 "host": "10.26.152.25",
                 "path": "/api/"}
             }
          }
       }]
    }

The properties of the `credentials` object serve two
purposes. Firstly, for backwards compatibility with other cloud
messaging providers, the `uri`, `vhost`, `username` `password` and
`hostname` properties are provided directly. However, these will only
ever reflect access to RabbitMQ over AMQP. Using these properties is
discouraged.

Secondly, a more flexible approach is provided by the
`credentials.protocols` object. This object has a key per protocol
enabled in the RabbitMQ broker. In this example we have just the keys
`amqp` and `management`, but other possible keys include `mqtt` and
`stomp`. Note that if SSL is enabled via the installer, then the keys
for `amqp` and `management` will be adjusted to `amqp+ssl` and
`management+ssl` respectively. However other protocols are not
automatically adjusted for use with the supplied SSL keys and require
configuration by supplying a custom `rabbitmq.config` file via the
installer. The values associated with each of these keys gives access
credentials specific to each protocol. In all cases, a full URI is
provided, along with the individual components to facilitate ease of
use with client libraries that do not support the full URIs.


## Updating the `VCAP_SERVICES` environment variable

If you adjust the plugins and protocols enabled for RabbitMQ via the
installer you will need to force the `VCAP_SERVICES` environment
variables to be regenerated. In common with all services in Pivotal
Cloud Foundry, the `VCAP_SERVICES` environment variable for an
application is only modified when the application is bound to a
service instance. Thus to update it so that it reflects the current
set of protocols and features enabled in RabbitMQ, you need to unbind
the application from the relevant RabbitMQ service instance, then
rebind it, and then restart the application. The application should
then find updated environment variables reflecting the current set of
enabled protocols.

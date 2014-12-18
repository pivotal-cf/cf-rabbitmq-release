# RabbitMQ Release for BOSH

All packages are compiled from source with the exception of packages
which are run by VMs and so the code is architecture neutral to start
with. In the case of this release, that amounts to the Erlang code for
RabbitMQ.


## Deployable Jobs

Currently, there are five jobs:

* phantom

    This is a job with no process and an empty _monit_ script. It
    simply depends on all the packages. This is a good way to get all
    the packages installed on a machine so that you can then `bosh
    ssh` into the machine and develop. It's also useful to get a
    machine on the same network as the rabbitmq-server jobs for
    testing.

* rabbitmq-server

    This is a job that provides the rabbitmq service. It depends on
    the rabbitmq-server, erlang, and util-linux packages only. The
    rabbitmq-server package is the RabbitMQ generic unix
    tarball. However, that tarball is only designed to be setup, run
    and used by the same user, which does not match with our
    requirements here. It also does not provide any sort of init
    script (indeed, even the OCF script is not shipped with it). Thus
    along with the tarball, we also provide customised versions of the
    RedHat init script, rabbitmq-script-wrapper and rabbitmq-defaults,
    which we install in various suitable locations to make everything
    work rather like we expect a properly packaged rabbitmq-server to
    work. In our case here, RabbitMQ is run as the _vcap_ user,
    persistent storage (MNESIA_BASE) is `/var/vcap/store/rabbitmq`,
    logs are in `/var/vcap/sys/log/rabbitmq-server` and the PID_FILE
    is in `/var/vcap/sys/run/rabbitmq-server/pid`.

    An _init_ script is provided (customised from the upstream
    RabbitMQ _init_ scripts) that enables the requested plugins, and
    starts up the server. A _monit_ script is also provided to allow
    _monit_ to drive the _init_ script and thus start and stop
    RabbitMQ.

    We also ship the new Clusterer plugin, always enable it, and patch
    the rabbitmq-server startup script (called by the init script via
    wrapper) as necessary. The clusterer config file is (if generated)
    kept in `/var/vcap/store/rabbitmq/etc/rabbitmq/cluster.config`.

* haproxy

    This is a job that provides the haproxy daemon. The config is
    provided as a deployment manifest property
    `haproxy.config`. It is expected that the config is provided as a
    linebreak-less base64 encoded string. To this provided config are
    added global options setting the user, group, and daemon option.

    An _init_ script is provided for monit to play with.

* rabbitmq-haproxy

    This is pretty much the same as the haproxy job, but is much
    easier to configure to work with Rabbit: you just provide it with
    a list of IP addresses rather than the entire config.

* rabbitmq-broker

  The service broker that talks to the cloud controller and the
  rabbits. This is only needed if you want to integrate with Cloud
  Foundry. If you're just doing BOSH-deployed-Rabbit you don't need to
  worry about this at all.

## Deployment Manifests & Deploying

The following assume you've created a release, named it
`pivotalone-rabbit` and uploaded it. Note that the initial compilation
will likely take around 25 minutes, even with 4 compiliation
machines. The dependency chain of packages is such that there's no
benefit from using more than 4 compiliation machines.

To perform a deployment, run

    bosh -n deploy


### User Accounts

Service broker provisions vhosts and user accounts. To do so,
it communicate with a RabbitMQ node over [HTTP API](http://hg.rabbitmq.com/rabbitmq-management/raw-file/3f1ad1f2748b/priv/www/api/index.html) and
authenticates as administrator.

During deployment, the default (`guest`:`guest`) user is deleted.  To
specify administrator user credentials, use
`rabbitmq-server.administrator.username` and
`rabbitmq-server.administrator.password` properties.


### Unclustered Rabbit with no plugins

``` yaml
jobs:
- name: my-first-rabbit
  release: pivotalone-rabbit
  template:
  - rabbitmq-server
  instances: 1
  resource_pool: common
  persistent_disk: 7168
  networks:
  - name: cf1
    static_ips:
    - 10.10.16.10
  properties:
    rabbitmq-server:
      administrator:
        username: gw-adm1nstat0R
        password: oY736Z48jePD29J7G
```

Increase instances to increase the number of independent
(unclustered) Rabbits. Remember to specify additional IP addresses
if you do so (assuming static and not dynamic) and make sure your
resource pool has enough spare capacity. RabbitMQ will be deployed
and started.

### Unclustered Rabbit with plugins

``` yaml
jobs:
- name: my-second-rabbit
  release: pivotalone-rabbit
  template:
  - rabbitmq-server
  instances: 1
  resource_pool: common
  persistent_disk: 7168
  networks:
  - name: cf1
    static_ips:
    - 10.10.16.10

properties:
  rabbitmq-server:
    plugins:
    - rabbitmq_management
    - rabbitmq_management_visualiser
    - rabbitmq_mqtt
    administrator:
      username: gw-adm1nstat0R
      password: oY736Z48jePD29J7G
```

The specified plugins will be enabled and RabbitMQ will be
started. The `rabbitmq-server` job plugins template simply
inspects a `rabbitmq-server.plugins` property and assumes it's a
list, enumerating through it and enabling plugins with that
name. You will get an error if you specify a non-existent plugin
name.

However, consider that you want to deploy two different RabbitMQ
servers with different plugins enabled. To do this, we make use of
`property-mappings` to specify different `rabbitmq-server`
properties for different jobs:

``` yaml
jobs:
- name: my-second-rabbit
  release: pivotalone-rabbit
  template:
  - rabbitmq-server
  instances: 1
  resource_pool: common
  persistent_disk: 7168
  networks:
  - name: cf1
    static_ips:
    - 10.10.16.10
  property_mappings:
    rabbitmq-server: my-second-rabbit

- name: my-third-rabbit
  release: pivotalone-rabbit
  template:
  - rabbitmq-server
  instances: 1
  resource_pool: common
  persistent_disk: 7168
  networks:
  - name: cf1
    static_ips:
    - 10.10.16.11
  property_mappings:
    rabbitmq-server: my-third-rabbit

properties:
  my-second-rabbit:
    plugins:
    - rabbitmq_management
    - rabbitmq_management_visualiser
    - rabbitmq_mqtt
    administrator:
      username: gw-adm1nstat0R
      password: oY736Z48jePD29J7G
  my-third-rabbit:
    plugins:
    - sockjs
    - rabbitmq_shovel
    administrator:
      username: gw-adm1nstat0R
      password: oY736Z48jePD29J7G
```

### Unclustered Rabbit with customised configuration

In the `properties` of the job you can specify a `config`. The value
must be a base64 encoded string of the `rabbitmq.config` you wish to
apply. Because BOSH treats the deployment manifest as an `erb` (even
though it just has the `yml` suffix), you can inject ruby directly and
thus achieve the encoding inline.

``` yaml
jobs:
- name: my-first-rabbit
  release: pivotalone-rabbit
  template:
  - rabbitmq-server
  instances: 1
  resource_pool: common
  persistent_disk: 7168
  networks:
  - name: cf1
    static_ips:
    - 10.10.16.10
  properties:
    rabbitmq-server:
      administrator:
        username: gw-adm1nstat0R
        password: oY736Z48jePD29J7G
      config: <%= ["[{rabbit, [{vm_memory_high_watermark,0.5}]}]."].pack("m0") %>
```

Make damn sure you get the config syntactically right: there's no
validation done and BOSH will sit there for 10 mins of Rabbit failing
to start if you get it wrong.

### Clustered Rabbit

``` yaml
jobs:
- name: my-clustered-rabbit
  release: pivotalone-rabbit
  template:
  - rabbitmq-server
  instances: 3
  resource_pool: common
  persistent_disk: 7168
  networks:
  - name: cf1
    static_ips:
    - 10.10.16.20
    - 10.10.16.21
    - 10.10.16.22
  property_mappings:
    rabbitmq-server: my-clustered-rabbit

properties:
  my-clustered-rabbit:
    cookie: mycookie
    static_ips:
    - 10.10.16.20
    - 10.10.16.21
    - 10.10.16.22
    plugins:
    - rabbitmq_management
    - rabbitmq_management_visualiser
    - rabbitmq_mqtt
    administrator:
      username: gw-adm1nstat0R
      password: oY736Z48jePD29J7G
```

In the properties section, the `cookie` entry is optional. The
`cookie` property determines the value of the Erlang cookie used for
RabbitMQ clustered. If omitted, a value will be generated based on
network details of the job.

The `static_ips` list must be identical to the `static_ips` given in
the job section itself.

Note that whenever the size of the cluster is changed, all nodes
within the RabbitMQ cluster will be restarted. It is not possible to
say whether or not there will be a period when all nodes are
down. Both of these aspects are due to the design of jobs within BOSH.

### Rabbit with SSL


``` yaml
jobs:
- name: my-rabbit
  release: pivotalone-rabbit
  template:
  - rabbitmq-server
  instances: 1
  resource_pool: common
  persistent_disk: 7168
  networks:
  - name: cf1
    static_ips:
    - 10.10.16.20
  property_mappings:
    rabbitmq-server: my-rabbit

properties:
  my-rabbit:
    plugins:
    - rabbitmq_management
    administrator:
      username: gw-adm1nstat0R
      password: oY736Z48jePD29J7G
    ssl:
      key: |
        -----BEGIN RSA PRIVATE KEY-----
        MIIEpAIBAAKCAQEAzg767NR3c+DMuMlFdAgWf0zr6xh5aFtOTRl4cS1gq7zQhHWs
        y2QTw2f5LOYLHl6sfh8kn3jLYqeUOTpEVML2XZ1MkZqQf7rYXtzjo8H44hBSYz/s
        uQOD+G9r/2OqRTuMwDvAi+8sp5GpUn9TEu8ERq9hU62MFDs3HvueB02+7Ts0OWZN
        O/rLbrVWRcXrrV4JG1poxYTmrEDcjDcj3qc5egY3yrNebTWPj6DDcEx8TJ8TqQLE
        K4bj8IpxmKu+tufqYTDlflPqy27YWaMfNhWjZU/XBR+4rPw5CGhY0KmSie9cFnjo
        T2LLBMcCMhYnye0EBnfCZNbbA54xPshI972xvwIDAQABAoIBAD/IR0eTpL4LsZLp
        SkRWVJBnAQeudbYlvSEEZ1GxGCFQusKloiz691sfDfQl6P8nkwEfJrjuLRaGhM0K
        CiiqiJQForPXQi8naN5ERXplCmL/ZmEuYloKiokWBDnzYbs4aaL/W+R0zj+4SM8u
        dkqADbTLiLbcG2YPxkoi3JGqMRVBFdp4LvPmbvWFmjYHr6IVibd2Ws4GqFUhoQqo
        FiRBOWaX7URrkipm83NnCMSjSSetAI0qOHr1rEBRFq068ZBKbhh1Ld9NgnAfOfsq
        hSKroGe+bpRvQ2iwkCxlt7FNgjEPcWIRIM1k965WoVADU0BiC9EP95uM94Iszv93
        xLZbOJECgYEA8M7KinRdIlV595wRfIdtql1CKgFMKamDqOW9R8dK6f0cLeL3UX6u
        A5+Aohekbm/Fx5rNzZlLPq41rScGsjNmzXfCP3ySsuX2whvBN6OrxGeqZkWS5zli
        I6BVvJt/xZ7NTnXHp2yAcHbEHxwWSsF/8TLV1xgA2bPKSLGyiILKDo0CgYEA2w73
        AebRsVO6oOuODL5xpa1PUECbSttkTrptBzh0/6i2ZrrstD3xWciR2vvgfckvgswF
        MKgdA+fh8TbKvv0oI+rHb3WIwwTR/LhWDQ/q+woUHBXepS7M7fIbSpJUsCOFkLnG
        ChxhuMfuWMr7Gj3KVFVWv6r4cW9Fi5EdEZ/IhHsCgYEAmYxyr/hlDqiMXiwBJnPA
        pNpUfy5Wn1Y84qyjlippBWzk1AmehDOPyDWjszf6HIVfCtkWE9yEk1JIXcG9zlFi
        Yu/TR+IqNLLYNou2F8FgnJsxl4cTlicMAgWRxfMtdRi+dyI5DfPsrkm84s1pFX/v
        EiDFJCNlH2w6N0I/wjYLm10CgYAgDExu5sn+23UOXefmTWZrCrPz1b/ib755FiUl
        TUkwrgohdW9z3ywUKpfMJdVuEaT1yctolu/HxoDzvURkNL1Oo+aRk+xyO55NDtro
        BlAmcg8HHNv55qLsnOMJQedJ7ah4x/UFPam+UuG389pQuIGFXQbX+7dlQRY3mP9b
        uLipSQKBgQCfZow03pxSDcErO3hbDatwp7CwAFU5VU+449SxX5vTOZqSLeRJK7dM
        bekvtIXEEIzRp7Ox3FbVEBhksBc36AxEtbE/BfJIYch5jYLFRaBhxronoSrxCTtR
        4iMKCj3NU92sJUb8t3qQhR+9ZvmKu6tUNpctKhyvhi7T997CgDk0gg==
        -----END RSA PRIVATE KEY-----
      cert: |
        -----BEGIN CERTIFICATE-----
        MIIC7TCCAdWgAwIBAgIBAjANBgkqhkiG9w0BAQUFADAiMREwDwYDVQQDEwhNeVRl
        c3RDQTENMAsGA1UEBxMEOTIyOTAeFw0xMzEwMDQxMzA0MTJaFw0xNDEwMDQxMzA0
        MTJaMCExDjAMBgNVBAMMBWhhemVsMQ8wDQYDVQQKDAZzZXJ2ZXIwggEiMA0GCSqG
        SIb3DQEBAQUAA4IBDwAwggEKAoIBAQDODvrs1Hdz4My4yUV0CBZ/TOvrGHloW05N
        GXhxLWCrvNCEdazLZBPDZ/ks5gseXqx+HySfeMtip5Q5OkRUwvZdnUyRmpB/uthe
        3OOjwfjiEFJjP+y5A4P4b2v/Y6pFO4zAO8CL7yynkalSf1MS7wRGr2FTrYwUOzce
        +54HTb7tOzQ5Zk07+stutVZFxeutXgkbWmjFhOasQNyMNyPepzl6BjfKs15tNY+P
        oMNwTHxMnxOpAsQrhuPwinGYq7625+phMOV+U+rLbthZox82FaNlT9cFH7is/DkI
        aFjQqZKJ71wWeOhPYssExwIyFifJ7QQGd8Jk1tsDnjE+yEj3vbG/AgMBAAGjLzAt
        MAkGA1UdEwQCMAAwCwYDVR0PBAQDAgUgMBMGA1UdJQQMMAoGCCsGAQUFBwMBMA0G
        CSqGSIb3DQEBBQUAA4IBAQC6c7MO4V9SyyqFPNbBS5pTD2SCkLzq8wnvjOuxcrg+
        yL7bFE8A9O4EDMMQtzOa9g2uMc35LqMbko9k5BXplciteGETH9GawCOb9zZKuFP5
        8EokoDpx3VvUiVIVORSZLpna2mzPkNO1Tx28fWL8D++KB3IPKv6G3hGrBigGxFiv
        f062MCnnPG5Kdc8Be9S4Fb29HDlOYScO62Bpe89J9RGoBHng8TlE3WnsyqMY/zAy
        WwLJhsi+lzvyWqT/FfH3/+JeIovbzyP3CVASz7hGg2+xOQ8LhhFeGHMgPPICGQns
        G10igwryZmanKDPCLRqf6m4Q5MOkDfU+1v7RrI+Dy1SI
        -----END CERTIFICATE-----
      cacert: |
        -----BEGIN CERTIFICATE-----
        MIIC5DCCAcygAwIBAgIJAIzv1n3WJEeJMA0GCSqGSIb3DQEBBQUAMCIxETAPBgNV
        BAMTCE15VGVzdENBMQ0wCwYDVQQHEwQ5MjI5MB4XDTEzMTAwNDEzMDQxMVoXDTE0
        MTAwNDEzMDQxMVowIjERMA8GA1UEAxMITXlUZXN0Q0ExDTALBgNVBAcTBDkyMjkw
        ggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDLu6lEEpjmk1f/rYMo5lJi
        FF2HQuG+P47zKH8HoVoTP0q6ACkA2BA25XQX80RGot4tn5YiyenFXUR1EgSA64rp
        7fcjl44GWw20PEvYdd8UGzA+fEYQxWeSGDl/3jrQt4WJCtIhKgKvYlJb9WJACf5N
        JdU2bNu1F78FtK+HIWgerRyjcDXGx3iFUPZ51onNoC5QS4nT9toRXzilO4RmEO9q
        fOWrVcIjnmoPuU12v54MVz10q9a2wL4HzLH8tGJgAnguFUs+ahUHmC80bSkl54v0
        AlABDc844NG9BgW62sAvNFFf8XfOTyybnIFHt5j14usmbmF2fINwXdYY2hrWSZrj
        AgMBAAGjHTAbMAwGA1UdEwQFMAMBAf8wCwYDVR0PBAQDAgEGMA0GCSqGSIb3DQEB
        BQUAA4IBAQAFiZxiREy7hbB7/wDyAXgvUUtm51Tzlme9YIBfkIDIZXLEG+xOn/yO
        FVniLE/qcWphJzawrkxMuyYWy4Adcsj6hMXqo15kVppNlOonLy+ElgU4lT1QoQdT
        rLqlCLJQE2bdP7C89UcO9pCgMe66ftuO5ORli95XFIFR0qctG8jFzyFLPPJaRhHz
        d9IXXnidj3H6TP90IAOnglgfahQQNhZOVBrCJEkuQPqAH3OMwadTceg893Jx6E8G
        Rb/2el7ucFqDTsky9YwdjoPX7gPaDLad5BDiGgHNfm63yKzncg3uAKH48GTdUeJQ
        WjmFBOwG1p4Fbs+HRgNFxkPqoMLucSVL
        -----END CERTIFICATE-----
```

When you provide `ssl` certs and keys, Rabbit will stop listening on
port 5672 for AMQP, and will instead listen on port 5671 for AMQP over
SSL. The SSL certs are also provided to the Management plugin, which
if enabled, will continue to listen on port 15672, but will only
respond to HTTPS, not HTTP.

### Service Gateway

Before you can deploy a service gateway (aka broker) job, you need to
have a [running CloudFoundry
instance](http://docs.cloudfoundry.com/docs/running/deploying-cf/ec2/index.html#deploy-cloudfoundry).

Below is an example of a relevant deployment manifest section.  Make
sure you substitute `[account name]` with your actual account name in
[deployments-aws](https://github.com/cloudfoundry/pivotalone-rabbit),
e.g.

    http://api.mklishin.cf-app.com

UAA credentials and a lot of other generated information can be found
in the CF AWS deployment manifest (typically `deployments-aws/[account
name]/cf-aws.yml`).


``` yaml
jobs:
- name: rabbitmq_gateway
  release: pivotalone-rabbit
  template: rabbitmq_gateway
  instances: 1
  resource_pool: common
  persistent_disk: 1024
  networks:
  - name: cf1
    static_ips:
    # make sure this IP is unique
    - 10.10.16.121
  properties:
    rabbitmq_gateway:
      cc_endpoint: http://api.[account name].cf-app.com
      cc_api_version: v2
      uaa_endpoint: http://uaa.[account name].cf-app.com
      uaa_client:
        client_id: "cf"
        username: services
        password: [services user password from cf-aws.yml]
      rabbitmq:
        hosts:
        - 10.10.16.20
        - 10.10.16.21
        - 10.10.16.22
        administrator:
          username: gw-adm1nstat0R
          password: oY736Z48jePD29J7G
        ssl: false
      logging:
        level: info
      service:
        label: rabbitmq
        provider: pivotal
        unique_id: 0aa2f82c-6918-41df-b676-c275b5954ed7
        version: "1.0"
        description: 'RabbitMQ service'
        url: http://10.10.16.121:4567
        auth_token: "367@8G24#e:3pTVwD.ng,YMJKds9<X"
        plans:
          free:
            name: Free
            unique_id: 72a39c18-c324-4f31-8db3-1676253c4385
            description: "Free as in beer"
            free: true
            public: true
        default_plan: free
        tags: ['rabbitmq', 'messaging', 'message-queue', 'amqp', 'mqtt', 'stomp']
        supported_versions: ['3.1']
        version_aliases:
          'current': '3.1'
        # required attribute!
        extra: ""
```

Be sure to add the `rabbitmq.adminstrator` hash to the properties of
the indicated `rabbitmq-server` job. E.g.

``` yaml
- name: my-clustered-rabbit
  release: pivotalone-rabbit
  template:
  - rabbitmq-server
  instances: 3
  resource_pool: common
  persistent_disk: 7168
  networks:
  - name: cf1
    static_ips:
    - 10.10.16.20
    - 10.10.16.21
    - 10.10.16.22
  property_mappings:
    rabbitmq-server: my-clustered-rabbit

properties:
  my-clustered-rabbit:
    cookie: mycookie
    static_ips:
    - 10.10.16.20
    - 10.10.16.21
    - 10.10.16.22
    plugins:
    - rabbitmq_management
    - rabbitmq_management_visualiser
    - rabbitmq_mqtt
    administrator:
      username: gw-adm1nstat0R
      password: oY736Z48jePD29J7G
```

If you are using SSL for your Rabbits, be sure to turn the `ssl` key
to `true` in the `rabbitmq` section of the properties for the gateway:

``` yaml
jobs:
- name: rabbitmq_gateway
  release: pivotalone-rabbit
  template: rabbitmq_gateway
  instances: 1
  resource_pool: common
  persistent_disk: 1024
  networks:
  - name: cf1
    static_ips:
    # make sure this IP is unique
    - 10.10.16.121
  properties:
    rabbitmq_gateway:
      cc_endpoint: http://api.[account name].cf-app.com
      cc_api_version: v2
      uaa_endpoint: http://uaa.[account name].cf-app.com
      uaa_client:
        client_id: "cf"
        username: services
        password: [services user password from cf-aws.yml]
      rabbitmq:
        hosts:
        - 10.10.16.20
        - 10.10.16.21
        - 10.10.16.22
        administrator:
          username: gw-adm1nstat0R
          password: oY736Z48jePD29J7G
        ssl: true
      ...
```

With SSL on, the service gateway will expect to find the management
plugin running on the indicated RabbitMQ hosts on port 15672 with
HTTPS, otherwise it'll assume port 15672 with plain HTTP.

With SSL on, the service gateway will return `amqps://` URIs to the
cloud controller upon binding, which are to be interpreted as port
5671 and AMQP over SSL. Otherwise, it'll return `amqp://` URIs to the
cloud controller which are to be interpreted as port 5672 and plain
AMQP.

### rabbitmq-haproxy

``` yaml
- name: haproxy
  release: pivotalone-rabbit
  template: rabbitmq-haproxy
  instances: 1
  resource_pool: common
  persistent_disk: 7168
  networks:
  - name: cf1
    static_ips:
    - 10.10.16.50
  properties:
    rabbitmq-haproxy:
      server_ips:
      - 10.10.16.20
      - 10.10.16.21
      - 10.10.16.22
      - 10.10.16.23
```

This is the sane way to configure haproxy for use with Rabbit. It will
attempt to proxy ports 5672 (AMQP), 5671 (AMQPS) and 15672
(Management, plain HTTP or HTTPS). For 15672 we use roundrobin. For
the others we use leastconn.

The general idea here is that you give it the IPs of the rabbit
servers, and then point the service gateway at the proxy rather than
the rabbit servers directly. Obviously the `server_ips` should match
entirely the `static_ips` of the `rabbitmq-server` job.

### haproxy

Note you probably don't want to use this in its raw form unless you
really need to set up an utterly custom haproxy.

``` yaml
- name: haproxy
  release: pivotalone-rabbit
  template: haproxy
  instances: 1
  resource_pool: common
  persistent_disk: 7168
  networks:
  - name: cf1
    static_ips:
    - 10.10.16.50
  property_mappings:
    haproxy: haproxy-1

properties:
  haproxy-1:
    config: "<%= ["\nglobal\n\tmaxconn 64000\n\tspread-checks 4\n\ndefaults\n\ttimeout connect 10000ms\n\nfrontend http-in \n\tbind :15672\n\tdefault_backend http-servers\n\nbackend http-servers\n\tmode tcp\n\tbalance roundrobin\n\tserver node0 10.10.16.20:15672 check inter 5000\n\tserver node1 10.10.16.21:15672 check inter 5000\n\tserver node2 10.10.16.22:15672 check inter 5000\n\tserver node3 10.10.16.23:15672 check inter 5000\n\nfrontend amqp-in\n\tbind :5672\n\tdefault_backend amqp-servers\n\nbackend amqp-servers\n\tmode tcp\n\tbalance leastconn\n\tserver node0 10.10.16.20:5672 check inter 5000\n\tserver node1 10.10.16.21:5672 check inter 5000\n\tserver node2 10.10.16.22:5672 check inter 5000\n\tserver node3 10.10.16.23:5672 check inter 5000\n\nfrontend amqps-in\n\tbind :5671\n\tdefault_backend amqps-servers\n\nbackend amqps-servers\n\tmode tcp\n\tbalance leastconn\n\tserver node0 10.10.16.20:5671 check inter 5000\n\tserver node1 10.10.16.21:5671 check inter 5000\n\tserver node2 10.10.16.22:5671 check inter 5000\n\tserver node3 10.10.16.23:5671 check inter 5000\n"].pack("m0") %>"
```

The entire haproxy config is expressed here, and must be base64
encoded with no linebreaks (the `0` in `m0`). To this config, the job
adds global options setting the user and group and the daemon option,
so do not give those here. Obviously, take care to construct the
config correctly. The example here sets up an haproxy assuming a
cluster of four rabbits that run the management plugin (so it proxies
both 5672 and 15672). **You may like to reconfigure the gateway to
point at the haproxy rather than individual rabbits.** This will
ensure that the apps using items provisioned by the service gateway go
through the proxy and are thus load balanced.

## Testing RabbitMQ-server Job

Testing the server is chiefly a problem of gaining access to the
network the rabbitmq-server is on. With the default BOSH AWS bootstrap
script and consequent use of VPC, this is a little involved and left
as an exercise to the dear reader.

However, if life is too short for such endeavours, you can use the
*phantom* job to create a machine on which no RabbitMQ-server is
running, but contains all the software and will be on the correct
network.

After shelling into that machine with `bosh ssh <phantom-job-name>/0
--gateway_host micro.<name>.cf-app.com --gateway_user vcap`, you
should be able to reach the RabbitMQ-servers and test them. You should
even (firewall and erlang cookie settings permitting) be able to use
tools like `rabbitmqctl` (after sourcing
`/var/vcap/packages/rabbitmq-server/enable`).


## Upgrading RabbitMQ-server

For unclustered Rabbits, this is simply a matter of updating the
generic tarball in the `src/rabbitmq-server` directory and creating a
new release. Provided there have been no radical changes to the
packaging, this should work fine. Data should be maintained: we use
`/var/vcar/store` (i.e. persistent disk) to store all Rabbit's
persistent data, and the new version should be able to make any and
all modifications to that as necessary.

Note that you'll need to edit paths in the
`packages/rabbitmq-server/{files,packaging}` files to point to the new
tarball.

Also note that whilst upgrades should Just Work, downgrades will not
and are not a supported operation for upstream RabbitMQ either.

For clustered Rabbits, things are a bit more complex and **are still
to be worked out**.


## Updating packages

Within this release, great effort has been made to ensure that we are
compiling all native binaries and not shipping native binaries. As is
custom with BOSH, to do this has required the invention of yet another
packaging system.

In general this works as follows:

- Every package has an `enable` file in its installation
  directory. For example `/var/vcap/packages/autoconf/enable`.
- If, to compile your new/updated package, you depend on a certain
  other package, you can activate that dependency by simply sourcing
  (i.e. with `source` or `.`) the `enable` file of the dependee.
- The enable file modifies the environment, setting various paths.
- The enable file is generated during the compilation of a package by
  the `gen_enable.sh` script which is provided by the `packages`
  package, which you should depend on and activate in your own
  `packaging` scripts by sourcing in its `enable` script (which is
  itself generated by the `packages` package's `gen_enable.sh`
  script!).

So the general structure of a package is then:

- `src/<name>/foo-src.tar.gz`

    The upstream tarball of the source of the package.

- `packages/<name>/spec`

    Ensure you list the direct compile-time dependencies (including
    the `packages` package) and the source tarball for your
    package. Note that the if package `X` has a compile-time
    dependency on package `Y` (declared through `X`'s `spec` file) and
    if package `Z` has a compile-time dependency on package `Z`
    (declared through `Y`'s `spec` file) then BOSH will ensure `Z` is
    compiled first, then installed on the machine which is compiling
    `Y` and then `Z` and `Y` are installed on the machine which is
    compiling `X`.

- `packages/<name>/packaging`

    This is the file that actually builds the package. You need to
    figure out how a package is built yourself. Activate any
    compile-time dependencies the package has (including the
    `packages` package) (i.e. you should activate everything you list
    as a dependency in the `spec` file), then build it into
    `${BOSH_INSTALL_TARGET}`. Then finally `source` in the
    `gen_enable.sh` script. You want to `source` it in so that in gets
    the same variable bindings as the packaging script - in particular
    it needs `${BOSH_INSTALL_TARGET}`. Obviously, there are other ways
    to achieve this, but I've just been sourcing it in.

    An example `packaging` file (for a mythical `dbus` package) is:

        # abort script on any command that exit with a non zero value
        set -e

        . /var/vcap/packages/autofoo/enable
        . /var/vcap/packages/expat/enable
        . /var/vcap/packages/packages/enable

        tar xzf dbus/dbus_1.6.12.orig.tar.gz
        cd dbus-1.6.12
        ./configure --prefix=${BOSH_INSTALL_TARGET}
        make
        make install
        cd ..
        . gen_enable.sh

    We see here that `dbus` would depend on `autofoo` (which itself is
    just a helpful wrapper providing `automake`, `autoconf` and
    `libtool`), the `expat` libraries, and the `packages` package
    (which provides the `gen_enable.sh` script). These are activated,
    thus supplimenting the local environment. We would then untar the
    source and go through the usual triple of `configure, make, make
    install` setting the `prefix` to
    `${BOSH_INSTALL_TARGET}`. Finally, after installation has
    succeeded, we source in the `gen_enable.sh` script. *Note that
    this should be done last as it searches through the installed
    package artifacts for items to suppliment the environment with,
    writing out what it finds to the `enable` file.*

    Note that the generated `enable` files only concern themselves
    with the package itself and not its dependencies. This is because
    the generated `enable` file is intended to be used both at
    compile-time and runtime and the compile-time and runtime
    dependencies of a package frequently differ.

    Currently, the `gen_enable.sh` script suppliments the `PATH`,
    `LD_LIBRARY_PATH`, `LIBRARY_PATH`, `CPATH`, `PKG_CONFIG_PATH` and
    `ACLOCAL_PATH` environment variables. There is a chance that in
    the future additional environment variables will need to be
    modified automatically by `gen_enable.sh` to enable compilation or
    operation of a package (or packages).

    Some packages have additional dependencies just to build their
    documentation, which are often painful to satisfy (e.g. consider
    the upstream documentation is written in _docbook_). With
    BOSH-installed packages it's unlikely that such documentation is
    ever going to be read, so you may wish to take steps to eliminate
    building the documentation. This is best done in the `packaging`
    script. Judicious use of `sed` and friends to edit out certain
    `Makefile` dependencies may be a viable strategy.

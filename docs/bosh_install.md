## Installing BOSH

There is nothing special about installing BOSH for the Cloud
Foundry RabbitMQ deployment. The following are reasonably generic but
by no means intended to be a canonical installation guide. Use at your
own risk. Equally, if you are familiar with BOSH and/or already have
your own BOSH deployment, you may not find much of interest on this
page.

### Set up microbosh

Follow [the
instructions](https://github.com/cloudfoundry/internal-docs/blob/master/getting_started.md)
to the point where you have a running microbosh. Those are AWS based
to a degree. For vSphere, these
[blog](http://www.think-foundry.com/build-cloud-foundry-vsphere-bosh-part-2/)
[entries](http://www.think-foundry.com/build-cloud-foundry-vsphere-bosh-part-3/)
seem reasonable.

### Create & upload a release

In your inception VM...

- `cd ~/workspace/deployments-aws/<name>`
- `git clone git@github.com:pivotal-cf/cf-rabbitmq-release.git && cd cf-rabbitmq-release`
- `bosh create release --with-tarball` (at the prompt, name the release
  `cf-rabbitmq`)
- `bosh upload release`

### Create a deployment and deploy it

#### AWS

- edit [`manifests/cf-rabbitmq-aws.yml`](https://github.com/pivotal-cf/cf-rabbitmq-release/blob/master/manifests/cf-rabbitmq-aws.yml)
  - set the `director_uuid` to the value shown by `bosh status --uuid`
  - set `networks.subnets.cloud_properties.subnet` to the value of
    `vpc.subnets.cf1` in `aws_vpc_receipt.yml`
- update cf domain in the properties section , hint search for `your_cc_endpoint.com`
- update cf related passwords in properties section such as:
	- `properties.cf.nats.username/password`
	- `properties.uaa_client.username/password`
- to change the rabbitmq administrator username / password change:
	- `properties.rabbitmq-server.administrators.broker.username/password`
	- `properties.rabbitmq-broker.administrators.username/password`
- add ssl certificates to the following sections if required:
	- `properties.rabbitmq-broker.rabbitmq.ssl`
	- `properties.rabbitmq-server.ssl`
- to configure rabbitmq plugins edit:
	- `properties.rabbitmq-server.plugins`
	
	For example:

		properties:
			rabbitmq-server:
				plugins:
				- rabbitmq_management
				- rabbitmq_mqtt
				- rabbitmq_stomp
	
- to enable tls 1.0 (required for JDK 6.0 support) add the following:
 
		properties
		  rabbitmq-server:
		    ssl:
			  security_options: 
			  - enable_tls1_0 			  
- make any required ip changes to the manifest depending on your AWS setup
- set the deployment manifest `bosh deployment manifests/cf-rabbitmq-aws.yml`
- deploy `bosh deploy`
- run `bosh vms` or similar to look at the status of the deployment

#### vSphere

For vSphere, you similarly want to prepare a deployment
manifest. Essentially it's a broadly similar process to AWS with
differences in particular to the `cloud_properties` entries. For
example, in `compilation` with AWS you're likely to have something
like:

    compilation:
      workers: 4
      network: cf1
      reuse_compilation_vms: true
      cloud_properties:
        instance_type: c1.medium
        availability_zone: us-east-1c

whereas in vSphere, you're going to have something like:

    compilation:
      workers: 4
      network: cf1
      cloud_properties:
        ram: 1024
        disk: 4096
        cpu: 2

On the whole, because vSphere isn't relying on arbitrary VPC
configurations and network names that have been decided for you by
`bosh aws bootstrap` and friends, it's much more logical - you can
give the networks names you want, etc. The network settings are
obviously very important to get right - the best source of info will
be the vSphere client, but you can basically figure out most things
from judicious use of `ifconfig`, `route` and `ping` should you have
access to some sort of *inception* VM on the same network. [This blog
post](http://www.think-foundry.com/build-cloud-foundry-vsphere-bosh-part-3/)
is worth reading regarding vSphere client and BOSH.

Here's an example network configuration:

    networks:
    - name: default
      subnets:
      - range: 10.150.28.0/22
        reserved:
        - 10.150.28.1 - 10.150.28.255
        - 10.150.29.1 - 10.150.29.50
        - 10.150.29.70 - 10.150.29.255
        - 10.150.30.1 - 10.150.30.255
        - 10.150.31.1 - 10.150.31.252
        static:
        - 10.150.29.51 - 10.150.29.69
        gateway: 10.150.31.253
        dns:
        - 10.17.193.1 # use your own DNS server IP
        - 10.17.193.2 # here too :)
        cloud_properties:
          name: "VM Network" #the VLAN that you are deploying BOSH to - provisioned on your vCenter

The `range` was determined from the destination address and netmask of
the non-default-route entries reported by `route -n` on the inception
VM (the /22 is CIDR representation of the 255.255.252.0 netmask). It
should be evident in the vSphere configuration too.

vSphere should be able to tell us which IP ranges are in
use. Alternatively, we can probe the network with `ping -c 2 -b
10.150.31.255` (the latter being the broadcast address of the
10.150.28.0/22 network).

Pick a range that doesn't overlap with the addresses in use and make
that the `static` range. The `reserved` range then is really just the
full `range` minus the `static` range.

The `gateway` address is taken from the default route entries reported
by `route -n` on the inception VM. It should also be available in
vSphere.

The `dns` addresses were taken from `/etc/resolv.conf` on the
inception VM; this information should also be available in vSphere.

The network name was taken from vSphere.

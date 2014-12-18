## Installing BOSH

There is nothing special about installing BOSH for the Pivotal Cloud
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
- `git clone git@github.com:cloudfoundry/pivotalone-rabbit.git && cd pivotalone-rabbit`
- `bosh create release --with-tarball` (at the prompt, name the release
  `pivotalone-rabbit`)
- `bosh upload release`

### Upload a stemcell

As per [a set of instructions we
found](https://github.com/cloudfoundry/internal-docs/blob/master/bosh/cheat.md#stemcells)...

- `wget http://bosh-jenkins-artifacts.s3.amazonaws.com/bosh-stemcell/aws/latest-bosh-stemcell-aws.tgz`
- `bosh upload stemcell latest-bosh-stemcell-aws.tgz`

### Create a deployment and deploy it

- `wget https://github.com/cloudfoundry/cf-release/raw/master/templates/cf-aws-template.yml.erb`
- `cp cf-aws-template.yml.erb pivotalone-rabbit.yml`

#### AWS

The following are for AWS and largely avoid you learning actually what
the different sections are about or for. Some of the older
vSphere-based blogs and docs are useful for explaining the intent,
even if they're a little out of date regarding the details.

- edit `pivotalone-rabbit.yml`
  - strip out the comment at the beginning
  - strip out all jobs and properties at the end (leave just `jobs: []` and `properties: {}`
  - remove all resource pools except `common`
  - set the `name` to `pivotalone-rabbit`
  - set the `director_uuid` to the value shown by `bosh status`
  - set `releases.name` to `pivotalone-rabbit`
  - (optional) set `compilation.workers` to `1`
  - set `compilation.cloud_properties.availability_zone` and
    `resource_pools[common].cloud_properties.availability_zone` to the
    value of `original_configuration.vpc.subnets.cf1.availability_zone`
    in `aws_vpc_receipt.yml`
  - set `networks.subnets.cloud_properties.subnet` to the value of
    `vpc.subnets.cf1` in `aws_vpc_receipt.yml`
  - (optional) set `resource_pools[common].size` to `4`
  - copy&paste some of the deployment manifest snippets below, with the
    following substitutions:
    - `my-resource-pool` -> `common`
    - `mynetwork` -> `cf1`
- `bosh deployment pivotalone-rabbit.yml`
- `bosh deploy`

You should now have some running rabbit(s). Quite how you can tell is
left as an exercise to the reader.

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

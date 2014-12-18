# Creating a Release

Currently this is done manually, but hopefully soon large parts of
this will be done automatically by CI.

1. Figure out what version you're going to use. If all is well, you
should be able to use `git tag -l` to see the existing tags and thus
identify which versions have already been used.

2. Either create release build via `bosh create-release --with-tarball
--force`, or if CI is working then grab the relevant release build out
of CI. Be sure to check which repo commit the build is based on. If CI
is fully working, it's possible it'll also be doing all the steps from
here to 6.

3. Update the metadata in the `metadata` directory so that the name and
MD5sum of the release is correct, and update the version. There are
currently two places in the metadata that require the version
(`product_version` and `provides_product_versions.version`). If the
RabbitMQ version has changed update the metadata for that too. There
are currently five current occurrences of `3.1.5` in the
metadata. These should all get changed at the same time.

4. Update the `content_migrations` file. The structure and contents of
this file are currently undocumented. And as there's only been one
release so far, the file also doesn't exist. But in future releases it
will exist, and should be checked in, probably in a
`content_migrations` directory.

5. Now create and populate a directory structure for building the zip:
    
        build/
            content_migrations/p_rabbitmq.yml
            metadata/p_rabbitmq.yml
            releases/cf-rabbitmq-0....-dev.tgz
            stemcells/bosh-stemcell-....-vsphere-esxi-centos.tgz

6. Build the zip.
        build $> zip -r ../p_rabbitmq.zip *

7. Now test the zip file in Ops Manager. Check upgrades and all that stuff
works too.

8. Assuming you're happy with it all, upload it to S3 buckets. We've
really no idea what the process is going to be for this going
forwards. For the initial release it went into both the
`assets_from_rabbit` bucket in the Ops Manager AWS account
(https://072360076281.signin.aws.amazon.com/console) and also Tami's
bucket (https://371887790748.signin.aws.amazon.com/console). I don't
know from which bucket the zip was actually taken to be
published. Also there was talk about updates being done in lockstep
quarterly. I have no idea who's going to coordinate that.

9. Back in the git repo, make sure the metadata and content_migrations
are the ones you just released, checked in. Add a tag with `git tag -a
release_a.b.c.d`, then push the tags with `git push --tags`. Check in
github that the tags actually have shown up.

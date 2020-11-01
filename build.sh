#!/usr/bin/env bash

set -x
set -e

yum -y install epel-release

yum -y install \
    perl-HTTP-Daemon-SSL

install --mode=0755 --directory /srv/uahttp/
cp -r app/* /srv/uahttp/

yum clean all
rm -rf /var/cache/yum
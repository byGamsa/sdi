#!/usr/bin/env bash

GEN_DIR=$(dirname "$0")/../gen

if [ $# -lt 2 ]; then
   echo usage: .../bin/scp ${devopsUsername}@${dnsName} ...
else
   scp -o UserKnownHostsFile="$GEN_DIR/known_hosts" $@
fi
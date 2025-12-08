#!/usr/bin/env bash

GEN_DIR=$(dirname "$0")/../gen

if [ $# -lt 2 ]; then
   echo usage: ./bin/scp <arguments>
else
   scp -o UserKnownHostsFile="$GEN_DIR/known_hosts" ${user}@${host} $@
fi
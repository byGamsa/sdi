#!/bin/bash
echo "Waiting for apt-cacher-ng on ${interface}:3142 ..." // [!code ++:6]
while ! nc -z ${interface} 3142; do
  sleep 8
  echo "apt-cacher-ng not yet ready ..."
done

echo "apt-cacher-ng service ready"
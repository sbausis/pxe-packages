#!/bin/bash

set -e
set -x

wget -qq -O - http://pxe.omv-extras.org/packages | (while read line; do
	echo "http://pxe.omv-extras.org/${line}"
done) > /media/5fd18e51-966f-4664-b9cf-999c23d2855f/debarchive/sources/pxe-packages.list

#echo "http://UniverseNAS.0rca.ch/sources/pxe-packages/xyz.tar.gz" >> /media/5fd18e51-966f-4664-b9cf-999c23d2855f/debarchive/sources/pxe-packages.list

exit 0

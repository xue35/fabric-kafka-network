#!/bin/bash -eu
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

##################################################
# This script pulls docker images from $DOCKER_NS
# docker hub repository and Tag it as
# $DOCKER_NS/fabric-<image> latest tag
##################################################

dockerFabricPull() {
  local FABRIC_TAG=$1
  for IMAGES in peer orderer couchdb ccenv kafka tools zookeeper; do
      echo "==> FABRIC IMAGE: $IMAGES"
      echo
      docker pull $DOCKER_NS/fabric-$IMAGES:$FABRIC_TAG
      docker tag $DOCKER_NS/fabric-$IMAGES:$FABRIC_TAG hyperledger/fabric-$IMAGES
  done
}

dockerCaPull() {
      local CA_TAG=$1
      echo "==> FABRIC CA IMAGE"
      echo
      docker pull $DOCKER_NS/fabric-ca:$CA_TAG
      docker tag $DOCKER_NS/fabric-ca:$CA_TAG hyperledger/fabric-ca
}

usage() {
      echo "Description "
      echo
      echo "Pulls docker images from hyperledger dockerhub repository"
      echo "tag as hyperledger/fabric-<image>:latest"
      echo
      echo "USAGE: "
      echo
      echo "./download-dockerimages.sh [-c <fabric-ca tag>] [-f <fabric tag>] [-p <image provider name>]"
      echo "      -c fabric-ca docker image tag"
      echo "      -f fabric docker image tag"
      echo
      echo
      echo "EXAMPLE:"
      echo "./download-dockerimages.sh -c 1.1.1 -f 1.1.0"
      echo
      echo "By default, pulls the 'latest' fabric-ca and fabric docker images"
      echo "from hyperledger dockerhub"
      exit 0
}

while getopts "\?hc:f:p:" opt; do
  case "$opt" in
     c) CA_TAG="$OPTARG"
        echo "Pull CA IMAGES"
        ;;

     f) FABRIC_TAG="$OPTARG"
        echo "Pull FABRIC TAG"
        ;;
     p) DOCKER_NS="$OPTARG"
        echo "Set image provider"
        ;;
     \?|h) usage
        echo "Print Usage"
        ;;
  esac
done

: ${DOCKER_NS:="hyperledger"}
: ${CA_TAG:="latest"}
: ${FABRIC_TAG:="latest"}

echo "===> Pulling fabric Images"
dockerFabricPull ${FABRIC_TAG}

echo "===> Pulling fabric ca Image"
dockerCaPull ${CA_TAG}
echo
echo "===> List out hyperledger docker images"
docker images | grep hyperledger

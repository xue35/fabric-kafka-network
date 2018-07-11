#!/bin/bash +x
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
#set -e

CHANNEL_NAME=$1
: ${CHANNEL_NAME:="mychannel"}
echo $CHANNEL_NAME

export FABRIC_ROOT=$PWD
export FABRIC_CFG_PATH=$PWD
echo

OS_ARCH=$(echo "$(uname -s|tr '[:upper:]' '[:lower:]'|sed 's/mingw64_nt.*/windows/')-$(uname -m | sed 's/x86_64/amd64/g')" | awk '{print tolower($0)}')

## Using docker-compose template replace private key file names with constants
function replacePrivateKey () {
	ARCH=`uname -s | grep Darwin`
	if [ "$ARCH" == "Darwin" ]; then
		OPTS="-it"
	else
		OPTS="-i"
	fi

	cp docker-compose-e2e-template.yaml docker-compose-e2e.yaml

        CURRENT_DIR=$PWD
        cd crypto-config/peerOrganizations/org1.example.com/ca/
        PRIV_KEY=$(ls *_sk)
        cd $CURRENT_DIR
        sed $OPTS "s/CA1_PRIVATE_KEY/${PRIV_KEY}/g" docker-compose-e2e.yaml
        cd crypto-config/peerOrganizations/org2.example.com/ca/
        PRIV_KEY=$(ls *_sk)
        cd $CURRENT_DIR
        sed $OPTS "s/CA2_PRIVATE_KEY/${PRIV_KEY}/g" docker-compose-e2e.yaml
}

## Generates Org certs using cryptogen tool
function generateCerts (){

	echo
	echo "##########################################################"
	echo "##### Generate certificates using cryptogen tool #########"
	echo "##########################################################"
	CRYPTOGEN_CMD="docker run --rm -v ${FABRIC_ROOT}:/fabric hyperledger/fabric-tools /usr/local/bin/cryptogen generate --config=/fabric/crypto-config.yaml --output=/fabric/crypto-config"
	echo "# $CRYPTOGEN_CMD"
	eval "$CRYPTOGEN_CMD"
	echo
}

function generateIdemixMaterial (){
	echo
	echo "####################################################################"
	echo "##### Generate idemix crypto material using idemixgen tool #########"
	echo "####################################################################"

	# Generate the idemix issuer keys
	# $IDEMIXGEN ca-keygen
	CONFIGTXGEN_CMD="docker run --rm --env FABRIC_CFG_PATH=/fabric -v ${FABRIC_ROOT}:/fabric hyperledger/fabric-tools /usr/local/bin/idemixgen ca-keygen --output=/fabric/crypto-config/idemix/idemix-config"
	echo "# ${CONFIGTXGEN_CMD}"
	eval "${CONFIGTXGEN_CMD}"

	# Generate the idemix signer keys
	# $IDEMIXGEN signerconfig -u OU1 -e OU1 -r 1
	CONFIGTXGEN_CMD="docker run --rm --env FABRIC_CFG_PATH=/fabric -v ${FABRIC_ROOT}:/fabric hyperledger/fabric-tools /usr/local/bin/idemixgen signerconfig -u OU1 -e OU1 -r 1 --output=/fabric/crypto-config/idemix/idemix-config"
	echo "# ${CONFIGTXGEN_CMD}"
	eval "${CONFIGTXGEN_CMD}"

	# cd $CURDIR
}

## Generate orderer genesis block , channel configuration transaction and anchor peer update transactions
function generateChannelArtifacts() {

	target=$FABRIC_ROOT/channel-artifacts
	if [ ! -d $target ]; then	
		echo "# Create director ${target}."
		mkdir -p ${target}
	fi

	echo "##########################################################"
	echo "#########  Generating Orderer Genesis block ##############"
	echo "##########################################################"
	# Note: For some unknown reason (at least for now) the block file can't be
	# named orderer.genesis.block or the orderer will fail to launch!
	CONFIGTXGEN_CMD="docker run --rm --env FABRIC_CFG_PATH=/fabric -v ${FABRIC_ROOT}:/fabric hyperledger/fabric-tools /usr/local/bin/configtxgen -profile TwoOrgsOrdererGenesis -outputBlock=/fabric/channel-artifacts/genesis.block -channelID e2e-orderer-syschan"
	echo "# ${CONFIGTXGEN_CMD}"
	eval "${CONFIGTXGEN_CMD}"

	echo
	echo "#################################################################"
	echo "### Generating channel configuration transaction 'channel.tx' ###"
	echo "#################################################################"
	CONFIGTXGEN_CMD="docker run --rm --env FABRIC_CFG_PATH=/fabric  -v ${FABRIC_ROOT}:/fabric hyperledger/fabric-tools /usr/local/bin/configtxgen -profile TwoOrgsChannel -outputCreateChannelTx /fabric/channel-artifacts/channel.tx -channelID $CHANNEL_NAME"
	echo "# ${CONFIGTXGEN_CMD}"
	eval "${CONFIGTXGEN_CMD}"

	echo
	echo "#################################################################"
	echo "#######    Generating anchor peer update for Org1MSP   ##########"
	echo "#################################################################"
	CONFIGTXGEN_CMD="docker run --rm --env FABRIC_CFG_PATH=/fabric  -v ${FABRIC_ROOT}:/fabric hyperledger/fabric-tools /usr/local/bin/configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate /fabric/channel-artifacts/Org1MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org1MSP"
	echo "# ${CONFIGTXGEN_CMD}"
	eval "${CONFIGTXGEN_CMD}"

	echo
	echo "#################################################################"
	echo "#######    Generating anchor peer update for Org2MSP   ##########"
	echo "#################################################################"
	CONFIGTXGEN_CMD="docker run --rm --env FABRIC_CFG_PATH=/fabric -v ${FABRIC_ROOT}:/fabric hyperledger/fabric-tools /usr/local/bin/configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate /fabric/channel-artifacts/Org2MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org2MSP"
	echo "# ${CONFIGTXGEN_CMD}"
	eval "${CONFIGTXGEN_CMD}"
	echo
}

generateCerts
generateIdemixMaterial
replacePrivateKey
generateChannelArtifacts

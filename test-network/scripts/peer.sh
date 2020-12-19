ROOTDIR=$(readlink -f $(dirname $BASH_SOURCE)/..)

cd $ROOTDIR

ORDERER=orderer.example.com
ASSETID=$(date +%s%N)
port=7050

export FABRIC_CFG_PATH=$ROOTDIR/../config

. scripts/envVar.sh

parsePeerConnectionParameters 1 2

PS4='+ $(date "+%F %T.%3N")\011 '

if [ "$1" == "chaincode_invoke" ] ; then
	set -x
	../bin/peer chaincode invoke \
				-o localhost:$port \
				--ordererTLSHostnameOverride $ORDERER \
				--tls \
				--cafile $ROOTDIR/organizations/ordererOrganizations/example.com/orderers/$ORDERER/msp/tlscacerts/tlsca.example.com-cert.pem \
				-C mychannel \
				-n basic \
				--peerAddresses localhost:7051 \
				--tlsRootCertFiles $ROOTDIR/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
				--peerAddresses localhost:9051 \
				--tlsRootCertFiles $ROOTDIR/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt \
				--waitForEvent \
				-c '{"function":"CreateAsset","Args":["asset'$ASSETID'", "gold", "7", "ACME", "'${VALUE:-1000}'"]}'
elif [ "$1" == "channel_getinfo" ] ; then
	set -x
	../bin/peer channel getinfo -c mychannel
elif [ "$1" == "snapshot_submitrequest_1" ] ; then
	set -x
	../bin/peer snapshot submitrequest \
				--peerAddress localhost:7051 \
				--tlsRootCertFile $ROOTDIR/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
				-c mychannel -b 0
elif [ "$1" == "snapshot_submitrequest" ] ; then
	set -x
	../bin/peer snapshot submitrequest \
				--peerAddress localhost:9051 \
				--tlsRootCertFile /root/tmp/fabric-samples/test-network/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt \
				-c mychannel -b $2
elif [ "$1" == "snapshot_cancelrequest" ] ; then
	set -x
	../bin/peer snapshot cancelrequest \
				--peerAddress localhost:9051 \
				--tlsRootCertFile /root/tmp/fabric-samples/test-network/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt \
				-c mychannel -b $2
elif [ "$1" == "snapshot_listpending" ] ; then
	set -x
	../bin/peer snapshot listpending \
				--peerAddress localhost:9051 \
				--tlsRootCertFile /root/tmp/fabric-samples/test-network/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt \
				-c mychannel
elif [ "$1" == "extract_snapshot" ] ; then
	set -x
	mkdir -p snapshots/$2
	docker cp peer0.org2.example.com:/var/hyperledger/production/snapshots/completed/mychannel/$2/. snapshots/$2 || exit 1
elif [ "$1" == "put_snapshot" ] ; then
	set -x
	docker exec Org3cli mkdir -p /tmp/snapshot
	docker cp snapshots/$2/. peer0.org3.example.com:/tmp/snapshot || exit 1
elif [ "$1" == "add_org3_step1" ] ; then
	set -x
	# https://hyperledger-fabric.readthedocs.io/en/latest/channel_update_tutorial.html
	cd addOrg3
	./addOrg3.sh step1
elif [ "$1" == "add_org3_step2_snapshot" ] ; then
	set -x
	cd addOrg3
	export JOINBYSNAPSHOT=/tmp/snapshot/$2
	time ./addOrg3.sh step2
elif [ "$1" == "add_org3_step2_genesis" ] ; then
	set -x
	cd addOrg3
	time ./addOrg3.sh step2
elif [ "$1" == "check_block" ] ; then
	set -x
	docker exec peer0.org1.example.com peer channel getinfo -c mychannel
	docker exec peer0.org2.example.com peer channel getinfo -c mychannel
	docker exec peer0.org3.example.com peer channel getinfo -c mychannel
else
	set -x
	../bin/peer chaincode query \
				-o localhost:$port \
				--ordererTLSHostnameOverride $ORDERER \
				--tls \
				--cafile $ROOTDIR/organizations/ordererOrganizations/example.com/orderers/$ORDERER/msp/tlscacerts/tlsca.example.com-cert.pem \
				-C mychannel \
				-n basic \
				-c '{"function":"GetAllAssets","Args":[]}'
fi

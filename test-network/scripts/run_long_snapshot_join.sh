ROOTDIR=$(readlink -f $(dirname $BASH_SOURCE)/..)

cd $ROOTDIR

./network.sh down
./network.sh up createChannel -ca -c mychannel -s couchdb -i 2.3.0
./network.sh deployCC -ccn basic -ccl go

# schedule snapshot at block 100
bash scripts/peer.sh snapshot_submitrequest 100

for i in $(seq 100) ; do
	VALUE=$i bash scripts/peer.sh chaincode_invoke
done

bash scripts/peer.sh channel_getinfo

bash scripts/peer.sh add_org3_step1
# copy snapshot to local
bash scripts/peer.sh extract_snapshot 100
# copy snapshot into Org3cli
bash scripts/peer.sh put_snapshot 100

# join peer0.org3.example.com from genesis block
if [ "$1" == snapshot ] ; then
	bash scripts/peer.sh add_org3_step2_snapshot
elif [ "$1" == genesis ] ; then
	bash scripts/peer.sh add_org3_step2_genesis
fi

bash scripts/peer.sh check_block

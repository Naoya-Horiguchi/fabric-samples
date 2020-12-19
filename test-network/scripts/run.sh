ROOTDIR=$(readlink -f $(dirname $BASH_SOURCE)/..)

cd $ROOTDIR

./network.sh down
./network.sh up createChannel -ca -c mychannel -s couchdb -i 2.3.0
./network.sh deployCC -ccn basic -ccl go

for i in $(seq 10) ; do
	bash scripts/peer.sh chaincode_invoke
done

bash scripts/peer.sh channel_getinfo

# block height 16

# take snapshot immediately
bash scripts/peer.sh snapshot_submitrequest 0

# schedule snapshot at block 20
bash scripts/peer.sh snapshot_submitrequest 20

# schedule snapshot at block 30
bash scripts/peer.sh snapshot_submitrequest 30

# check scheduled snapshot list
bash scripts/peer.sh snapshot_listpending

bash scripts/peer.sh snapshot_cancelrequest 30

bash scripts/peer.sh snapshot_listpending

# add few more blocks
for i in $(seq 5) ; do
	bash scripts/peer.sh chaincode_invoke
done

bash scripts/peer.sh channel_getinfo

# block height 21

bash scripts/peer.sh snapshot_listpending

bash scripts/peer.sh add_org3_step1
# copy snapshot to local
bash scripts/peer.sh extract_snapshot 20
# copy snapshot into Org3cli
bash scripts/peer.sh put_snapshot 20

# join peer0.org3.example.com from snapshot
bash scripts/peer.sh add_org3_step2_snapshot

bash scripts/peer.sh check_block

bash scripts/peer.sh chaincode_invoke

bash scripts/peer.sh check_block

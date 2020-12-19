# 台帳スナップショット機能の利用例

Hyperledger Fabric v2.3.0 で台帳スナップショットが利用できるようになりました。本記事ではサンプルコード test-network を少し改造してスナップショットを動かした様子について説明していきます。

台帳スナップショットの機能概要や制限事項の詳細については公式ドキュメントの [Taking ledger snapshots and using them to join channels](https://hyperledger-fabric.readthedocs.io/en/latest/peer_ledger_snapshot.html) に記載されています。peer に台帳データを全て保存しなくて済むためストレージの制限を回避できるのと、新たに peer を Fabric ネットワークに追加する際に全ての台帳データの同期を待たなくてよい、といったあたりが主な利点と言えます。

# 使い方

Hyperledger Fabric の[前提条件](https://hyperledger-fabric.readthedocs.io/en/release-2.3/prereqs.html)を満たした環境で、以下を実行すれば、必要な docker イメージがローカルに pull されます。

```
$ curl -sSL https://bit.ly/2ysbOFE | bash -s -- 2.3.0 1.4.9
```

少しサンプルコードを改造しているので変更分を checkout します。

```
$ cd fabric-samples/test-network
$ git fetch https://github.com/Naoya-Horiguchi/fabric-samples ledger_snapshot
$ git checkout -b tmp FETCH_HEAD
```

あとは、用意した[スクリプト](https://github.com/Naoya-Horiguchi/fabric-samples/blob/ledger_snapshot/test-network/scripts/run.sh) に実行すればスナップショットのスケジュール、作成、コピー、スナップショットを用いた組織の追加、といった機能の主要部分が実行されます。スクリプトをリンクするだけだと味気ないので、簡単に流れを紹介します。まずは通常どおり test-network を起動しています。

~~~
./network.sh down
./network.sh up createChannel -ca -c mychannel -s couchdb -i 2.3.0
./network.sh deployCC -ccn basic -ccl go

for i in $(seq 10) ; do
	bash scripts/peer.sh chaincode_invoke
done

bash scripts/peer.sh channel_getinfo
~~~

スナップショット取得コマンド `peer snapshot submitrequest` は `-b` オプションで取得するタイミングを指定します。最後にコミットされたブロック番号より小さい値を指定するとエラーになります。0 を与えると即スナップショットを取得します。

~~~
bash scripts/peer.sh snapshot_submitrequest 0
+ 2020-12-20 03:04:27.686        ../bin/peer snapshot submitrequest --peerAddress localhost:9051 --tlsRootCertFile /root/tmp/fabric-samples/test-network/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt -c mychannel -b 0
Snapshot request submitted successfully

bash scripts/peer.sh snapshot_submitrequest 20
+ 2020-12-20 03:04:27.753        ../bin/peer snapshot submitrequest --peerAddress localhost:9051 --tlsRootCertFile /root/tmp/fabric-samples/test-network/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt -c mychannel -b 20
Snapshot request submitted successfully

bash scripts/peer.sh snapshot_submitrequest 30
+ 2020-12-20 03:04:27.814        ../bin/peer snapshot submitrequest --peerAddress localhost:9051 --tlsRootCertFile /root/tmp/fabric-samples/test-network/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt -c mychannel -b 30
Snapshot request submitted successfully
~~~

`peer snapshot listpending` は未完了でスケジュール済みのスナップショットを確認できます。
~~~
bash scripts/peer.sh snapshot_listpending
+ 2020-12-20 03:04:27.872        ../bin/peer snapshot listpending --peerAddress localhost:9051 --tlsRootCertFile /root/tmp/fabric-samples/test-network/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt -c mychannel
Successfully got pending snapshot requests: [20 30]
~~~

キャンセルすることもできます。
~~~
bash scripts/peer.sh snapshot_cancelrequest 30
+ 2020-12-20 03:04:27.930        ../bin/peer snapshot cancelrequest --peerAddress localhost:9051 --tlsRootCertFile /root/tmp/fabric-samples/test-network/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt -c mychannel -b 30
Snapshot request cancelled successfully

bash scripts/peer.sh snapshot_listpending
+ 2020-12-20 03:04:27.990        ../bin/peer snapshot listpending --peerAddress localhost:9051 --tlsRootCertFile /root/tmp/fabric-samples/test-network/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt -c mychannel
Successfully got pending snapshot requests: [20]
~~~

数ブロック積んで再度確認してみると、スナップショットが処理されていることが分かります。
~~~
bash scripts/peer.sh channel_getinfo
+ 2020-12-20 03:04:38.647        ../bin/peer channel getinfo -c mychannel
2020-12-20 03:04:38.692 UTC [channelCmd] InitCmdFactory -> INFO 001 Endorser and orderer connections initialized
Blockchain info: {"height":21,"currentBlockHash":"QQz56TKkghA8a01mnbzaAmbx5HL6iotm2t2kC8XtQng=","previousBlockHash":"vs/Q5zyul32/syidybqrklTwIxo+tOOaVS8NfM4WnDk="}

bash scripts/peer.sh snapshot_listpending
+ 2020-12-20 03:04:38.707        ../bin/peer snapshot listpending --peerAddress localhost:9051 --tlsRootCertFile /root/tmp/fabric-samples/test-network/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt -c mychannel
Successfully got pending snapshot requests: []
~~~

次にスナップショットを用いて組織、peer を追加します。
~~~
bash scripts/peer.sh add_org3_step1
+ 2020-12-20 03:04:38.764        cd addOrg3
+ 2020-12-20 03:04:38.765        ./addOrg3.sh step1

... (出力省略)

========= Config transaction to add org3 to network submitted! ===========
~~~

スナップショットを取り出して新規追加する peer にコピーしています。
~~~
bash scripts/peer.sh extract_snapshot 20
+ 2020-12-20 03:04:40.801        mkdir -p snapshots/20
+ 2020-12-20 03:04:40.806        docker cp peer0.org2.example.com:/var/hyperledger/production/snapshots/completed/mychannel/20/. snapshots/20

bash scripts/peer.sh put_snapshot 20
+ 2020-12-20 03:04:40.931        docker exec Org3cli mkdir -p /tmp/snapshot
+ 2020-12-20 03:04:41.098        docker cp snapshots/20/. peer0.org3.example.com:/tmp/snapshot
~~~

最後にスナップショットを用いて join します。
~~~
bash scripts/peer.sh add_org3_step2_snapshot
+ 2020-12-20 03:04:41.235        cd addOrg3
+ 2020-12-20 03:04:41.236        export JOINBYSNAPSHOT=/tmp/snapshot/
+ 2020-12-20 03:04:41.237        JOINBYSNAPSHOT=/tmp/snapshot/
+ 2020-12-20 03:04:41.238        ./addOrg3.sh step2
Add Org3 to channel 'mychannel' with '10' seconds and CLI delay of '3' seconds and using database 'leveldb'


###############################################################
############### Have Org3 peers join network ##################
###############################################################

========= Getting Org3 on to your test network =========

Fetching channel config block from orderer...
+ peer channel fetch 0 mychannel.block -o orderer.example.com:7050 --ordererTLSHostnameOverride orderer.example.com -c mychannel --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
+ res=0
2020-12-20 03:04:41.419 UTC [channelCmd] InitCmdFactory -> INFO 001 Endorser and orderer connections initialized
2020-12-20 03:04:41.422 UTC [cli.common] readBlock -> INFO 002 Received block: 0
+ '[' /tmp/snapshot/ ']'
+ ls -l /tmp/snapshot/
total 0
+ peer channel joinbysnapshot --snapshotpath /tmp/snapshot/
+ res=0
2020-12-20 03:04:41.469 UTC [channelCmd] InitCmdFactory -> INFO 001 Endorser and orderer connections initialized
2020-12-20 03:04:41.473 UTC [channelCmd] executeJoin -> INFO 002 Successfully submitted proposal to join channel
2020-12-20 03:04:41.473 UTC [channelCmd] joinBySnapshot -> INFO 003 The joinbysnapshot operation is in progress. Use "peer channel joinbysnapshotstatus" to check the status.
===================== peer0.org3 joined channel 'mychannel' =====================

========= Finished adding Org3 to your test network! =========
~~~

# 確認しておきたいポイント

スナップショットファイルはスナップショット処理を実行した peer のコンテナ内に作成されます。スナップショットファイルの保存先のパスは `core.yaml` の [`ledger.snapshot.rootDir`](https://github.com/hyperledger/fabric/blob/v2.3.0/sampleconfig/core.yaml#L697) で指定できます。スナップショットを取った後に peer 内の当該パスを見てみると、いろいろスナップショットの実体について見ることができます。

~~~
root@ip-172-31-33-71:~/tmp/fabric-samples/test-network# docker exec peer0.org2.example.com find /var | grep snapshot
/var/hyperledger/production/snapshots
/var/hyperledger/production/snapshots/completed
/var/hyperledger/production/snapshots/completed/mychannel
/var/hyperledger/production/snapshots/completed/mychannel/15
/var/hyperledger/production/snapshots/completed/mychannel/15/private_state_hashes.metadata
/var/hyperledger/production/snapshots/completed/mychannel/15/_snapshot_signable_metadata.json
/var/hyperledger/production/snapshots/completed/mychannel/15/txids.metadata
/var/hyperledger/production/snapshots/completed/mychannel/15/private_state_hashes.data
/var/hyperledger/production/snapshots/completed/mychannel/15/txids.data
/var/hyperledger/production/snapshots/completed/mychannel/15/public_state.data
/var/hyperledger/production/snapshots/completed/mychannel/15/_snapshot_additional_metadata.json
/var/hyperledger/production/snapshots/completed/mychannel/15/public_state.metadata
/var/hyperledger/production/snapshots/completed/mychannel/20
/var/hyperledger/production/snapshots/completed/mychannel/20/private_state_hashes.metadata
/var/hyperledger/production/snapshots/completed/mychannel/20/_snapshot_signable_metadata.json
/var/hyperledger/production/snapshots/completed/mychannel/20/txids.metadata
/var/hyperledger/production/snapshots/completed/mychannel/20/private_state_hashes.data
/var/hyperledger/production/snapshots/completed/mychannel/20/txids.data
/var/hyperledger/production/snapshots/completed/mychannel/20/public_state.data
/var/hyperledger/production/snapshots/completed/mychannel/20/_snapshot_additional_metadata.json
/var/hyperledger/production/snapshots/completed/mychannel/20/public_state.metadata
/var/hyperledger/production/snapshots/temp
~~~

各データファイルの内容はバイナリ形式なので直接は読めませんが、json 形式のメタデータファイルからいくつかヒントになりそうな情報が読み取れます。private data に関してはハッシュ値 (`private_state_hashes.data`) のみスナップショットに含まれる点は重要でしょう。

~~~
root@ip-172-31-33-71:~/tmp/fabric-samples/test-network# docker exec peer0.org2.example.com ls -l /var/hyperledger/production/snapshots/completed/mychannel/20
total 52
-r--r--r--    1 root     root           189 Dec 20 01:40 _snapshot_additional_metadata.json
-r--r--r--    1 root     root           919 Dec 20 01:40 _snapshot_signable_metadata.json
-r--r--r--    1 root     root           889 Dec 20 01:40 private_state_hashes.data
-r--r--r--    1 root     root            74 Dec 20 01:40 private_state_hashes.metadata
-r--r--r--    1 root     root         23437 Dec 20 01:40 public_state.data
-r--r--r--    1 root     root            23 Dec 20 01:40 public_state.metadata
-r--r--r--    1 root     root          1366 Dec 20 01:40 txids.data
-r--r--r--    1 root     root             2 Dec 20 01:40 txids.metadata
root@ip-172-31-33-71:~/tmp/fabric-samples/test-network# docker exec peer0.org2.example.com cat /var/hyperledger/production/snapshots/completed/mychannel/20/_snapshot_signable_metadata.json
{
    "channel_name": "mychannel",
    "last_block_number": 20,
    "last_block_hash": "9a9f82a6f30a071245887fa0149573cf1384c55246be5e111dc3dc4e37089599",
    "previous_block_hash": "b4d892f60ff74f46592334eda45b305b11ab12666b1b01d995a8b9d68e11b29e",
    "snapshot_files_raw_hashes": {
        "private_state_hashes.data": "aa6913c9302b0454f7ef9f22fed6904527d80e1d6d179653d3333a55b86ec167",
        "private_state_hashes.metadata": "9cd6329c16f0bb27dd69a0335dc8b4bd99b41f87f705deed63137b6edc025868",
        "public_state.data": "f53473ae57a2c43c2758b7b673bc1429384316c0ad7272403409d03f8d96958a",
        "public_state.metadata": "cd3a0a22d62785f598eaa2f0f40ec0c5e1f1945d406cc26dc55c955502e7dab7",
        "txids.data": "a6311af6e0d9a6a8409d35623b56496b148dbd3a0b67f64cf348b789edd56027",
        "txids.metadata": "764c8a3561c7cf261771b4e1969b84c210836f3c034baebac5e49a394a6ee0a9"
    },
    "state_db_type": "CouchDB"
}
root@ip-172-31-33-71:~/tmp/fabric-samples/test-network#  docker exec peer0.org2.example.com cat /var/hyperledger/production/snapshots/completed/mychannel/20/_snapshot_additional_metadata.jso
{
    "snapshot_hash": "97dfdcd2795ea713731616a5cf5a92025c4f16fecaf8da62bdd3f671fcf0bf19",
    "last_block_commit_hash": "4123596d9f555997f27a7b07f98680b90346ded5d98ef68e8468c3701fe04b9e"
}
~~~

この例ではブロック 20 をターゲットに台帳スナップショットを作成し、それを起点に org3 を追加するというシナリオを試しています。サンプルコードには Fabric ネットワーク起動後に組織を追加する addOrg3 というスクリプトがありますが、ここを少し[改造する](https://github.com/Naoya-Horiguchi/fabric-samples/blob/ledger_snapshot/test-network/addOrg3/addOrg3.sh#L179)必要があります。もともと `addOrg3.sh` は「org3 の peer の準備、起動」と「チャネルへの追加」の 2 ステップに処理が分かれているのですが、これは今回の改造に都合がよく、ステップ 1 と 2 の間にコンテナ `peer0.org2.example.com` から取り出したスナップショットファイルをコンテナ `peer0.org3.example.com` 内に送り込み、ステップ 2 では join 処理を従来の `peer channel join` から `peer channel joinbysnapshot` に差し替えています。

~~~
+ peer channel joinbysnapshot --snapshotpath /tmp/snapshot/
+ res=0
2020-12-20 02:03:59.404 UTC [channelCmd] InitCmdFactory -> INFO 001 Endorser and orderer connections initialized
2020-12-20 02:03:59.407 UTC [channelCmd] executeJoin -> INFO 002 Successfully submitted proposal to join channel
2020-12-20 02:03:59.407 UTC [channelCmd] joinBySnapshot -> INFO 003 The joinbysnapshot operation is in progress. Use "peer channel joinbysnapshotstatus" to check the status.
~~~

`peer channel getinfo` の出力から org3 だけスナップショットから起動していることが読み取れます。

~~~
+ docker exec peer0.org1.example.com peer channel getinfo -c mychannel
2020-12-20 02:04:02.404 UTC [channelCmd] InitCmdFactory -> INFO 001 Endorser and orderer connections initialized
Blockchain info: {"height":23,"currentBlockHash":"s5hLxrjdtGNkdlyLvlzouQjL2FJp2SdEEKVg7q4kJuE=","previousBlockHash":"Nj59f84iFOO4gSr9z9cr1N0ixhelfsndyYnObuwfhUA="}
+ docker exec peer0.org2.example.com peer channel getinfo -c mychannel
2020-12-20 02:04:02.619 UTC [channelCmd] InitCmdFactory -> INFO 001 Endorser and orderer connections initialized
Blockchain info: {"height":23,"currentBlockHash":"s5hLxrjdtGNkdlyLvlzouQjL2FJp2SdEEKVg7q4kJuE=","previousBlockHash":"Nj59f84iFOO4gSr9z9cr1N0ixhelfsndyYnObuwfhUA="}
+ docker exec peer0.org3.example.com peer channel getinfo -c mychannel
2020-12-20 02:04:02.834 UTC [channelCmd] InitCmdFactory -> INFO 001 Endorser and orderer connections initialized
Blockchain info: {"height":23,"currentBlockHash":"s5hLxrjdtGNkdlyLvlzouQjL2FJp2SdEEKVg7q4kJuE=","previousBlockHash":"Nj59f84iFOO4gSr9z9cr1N0ixhelfsndyYnObuwfhUA=","bootstrappingSnapshotInfo":{"lastBlockInSnapshot":20}}
~~~

`peer0.org3.example.com` はブロック 20 以前のデータを持たないため、`peer channel fetch` コマンドで古いブロックを取得することができません。

~~~
root@ip-172-31-33-71:~/tmp/fabric-samples/test-network# docker exec -it peer0.org3.example.com peer channel fetch newest abc.block -c mychannel
2020-12-19 17:52:07.186 UTC [channelCmd] InitCmdFactory -> INFO 001 Endorser and orderer connections initialized
2020-12-19 17:52:07.188 UTC [cli.common] readBlock -> INFO 002 Received block: 21
root@ip-172-31-33-71:~/tmp/fabric-samples/test-network# docker exec -it peer0.org3.example.com peer channel fetch 10 abc.block -c mychannel
2020-12-19 17:52:20.190 UTC [channelCmd] InitCmdFactory -> INFO 001 Endorser and orderer connections initialized
2020-12-19 17:52:20.192 UTC [cli.common] readBlock -> INFO 002 Expect block, but got status: &{NOT_FOUND}
Error: can't read the block: &{NOT_FOUND}
~~~

スナップショットからの join ではコンテナ内に置かれている台帳ファイルのストレージ使用量に差があることも分かります。この差は台帳が長くなるにつれて顕著になるでしょう。

~~~
root@ip-172-31-33-71:~/tmp/fabric-samples/test-network# docker exec peer0.org2.example.com du -h -d 1 /var/hyperledger/production/ledgersData
20.0K   /var/hyperledger/production/ledgersData/historyLeveldb
20.0K   /var/hyperledger/production/ledgersData/pvtdataStore
252.0K  /var/hyperledger/production/ledgersData/chains
16.0K   /var/hyperledger/production/ledgersData/configHistory
20.0K   /var/hyperledger/production/ledgersData/ledgerProvider
20.0K   /var/hyperledger/production/ledgersData/bookkeeper
116.0K  /var/hyperledger/production/ledgersData/couchdbRedoLogs
16.0K   /var/hyperledger/production/ledgersData/fileLock
484.0K  /var/hyperledger/production/ledgersData
root@ip-172-31-33-71:~/tmp/fabric-samples/test-network# docker exec peer0.org3.example.com du -h -d 1 /var/hyperledger/production/ledgersData
20.0K   /var/hyperledger/production/ledgersData/historyLeveldb
20.0K   /var/hyperledger/production/ledgersData/pvtdataStore
80.0K   /var/hyperledger/production/ledgersData/chains
16.0K   /var/hyperledger/production/ledgersData/configHistory
20.0K   /var/hyperledger/production/ledgersData/ledgerProvider
16.0K   /var/hyperledger/production/ledgersData/bookkeeper
76.0K   /var/hyperledger/production/ledgersData/stateLeveldb
16.0K   /var/hyperledger/production/ledgersData/fileLock
268.0K  /var/hyperledger/production/ledgersData
~~~

スナップショットからの join と従来の genesis ブロックを用いた join でどのくらい処理時間に差が出るかも確認できます。ドキュメントに記載されているように、スナップショットからの join の方が少し処理時間が短くなっています。ただ、ブロックの高さ 20 の場合と 100 の場合を試してみましたが、有意な差は見られませんでした。もっとブロック長が大きくならないと差は実感できないのかもしれません。

~~~
join with snapshot

  real    0m0.281s
  user    0m0.033s
  sys     0m0.036s

join with genesis block

  real    0m0.322s
  user    0m0.060s
  sys     0m0.010s
~~~

# 気になること

スナップショット機能は台帳の全データをカバーするわけではないので、少なくとも現時点ではバックアップ目的で使用するものではないようです。
ストレージの節約目的で使う前提で、一つの組織内で少なくとも一つの peer は台帳の全データを持っている必要があり、その peer に負荷を集めないために commit peer や endorsing peer の役割を組織内で別 peer に分離して、それら peer の台帳をスナップショットベースで持つ、といった構成において効果が期待されます。
その限りでは機能的には十分と思いますが、一つ、「genesis ブロックからスタートした peer をランタイムでスナップショット方式に切り替えられるか」あたりが気になるところです。

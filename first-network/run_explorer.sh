privatekey=$(find crypto-config/ | grep peerOrganizations/org1.example.com/users/Admin@org1.example.com | grep _sk | xargs -r basename)

if [ ! "$privatekey" ] ; then
	echo "private key for Admin@org1.example.com not found, abort."
	exit 1
fi

sed -e "s/ORG1ADMIN_PRIVATEKEY/$privatekey/" explorer/examples/net1/connection-profile/first-network.json.template > explorer/examples/net1/connection-profile/first-network.json

docker-compose -f docker-compose-explorer.yaml up -d

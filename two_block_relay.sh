node_IP=$1
node_second_IP=$2
cat > $NODE_HOME/${NODE_CONFIG}-topology.json << EOF
 {
    "Producers": [
      {
        "addr": "${node_IP}",
        "port": 6000,
        "valency": 1
      },
      {
        "addr": "${node_second_IP}",
        "port": 6000,
        "valency": 1
      },
      {
        "addr": "relays-new.cardano-mainnet.iohk.io",
        "port": 3001,
        "valency": 2
      }
    ]
  }
EOF
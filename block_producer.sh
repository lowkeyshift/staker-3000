node_IP=$1
cat > $NODE_HOME/${NODE_CONFIG}-topology.json << EOF 
 {
    "Producers": [
      {
        "addr": "${node_IP}",
        "port": 6000,
        "valency": 1
      }
    ]
  }
EOF
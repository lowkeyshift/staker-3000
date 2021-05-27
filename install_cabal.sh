#!/bin/bash

# Dependencies
sudo apt-get update -y && 
sudo apt update -y && \
sudo apt-get upgrade -y && \
sudo apt install git jq bc
sudo apt-get install make automake rsync htop curl build-essential pkg-config libffi-dev libgmp-dev libssl-dev libtinfo-dev libsystemd-dev zlib1g-dev make g++ wget libncursesw5 libtool autoconf -y

# Install libsodium
mkdir $HOME/git
cd $HOME/git
git clone https://github.com/input-output-hk/libsodium
cd libsodium
git checkout 66f017f1
./autogen.sh
./configure
make
sudo make install

# May need update of version numbers
sudo ln -s /usr/local/lib/libsodium.so.23.3.0 /usr/lib/libsodium.so.23

sudo apt-get -y install pkg-config libgmp-dev libssl-dev libtinfo-dev libsystemd-dev zlib1g-dev build-essential curl libgmp-dev libffi-dev libncurses-dev libtinfo5

echo "NO YES" | curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh

# Will need version to be updated
cd $HOME
. "$HOME/.ghcup/env"
echo '. $HOME/.ghcup/env' >> "$HOME/.bashrc"
source .bashrc
ghcup upgrade
ghcup install cabal 3.4.0.0
ghcup set cabal 3.4.0.0

#Cluster Configuration
echo PATH="$HOME/.local/bin:$PATH" >> $HOME/.bashrc
echo export LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH" >> $HOME/.bashrc
echo export NODE_HOME=$HOME/cardano-my-node >> $HOME/.bashrc
echo export NODE_CONFIG=mainnet>> $HOME/.bashrc
echo export NODE_BUILD_NUM=$(curl https://hydra.iohk.io/job/Cardano/iohk-nix/cardano-deployment/latest-finished/download/1/index.html | grep -e "build" | sed 's/.*build\/\([0-9]*\)\/download.*/\1/g') >> $HOME/.bashrc
source $HOME/.bashrc

#Print out version
echo "===-=====-=-==-====--===-=-====-==-=-=-=="
cabal update
cabal --version
ghc --version
echo "===-=====-=-==-====--===-=-====-==-=-=-=="

# Download Source code and switch to latest tag
cd $HOME/git
git clone https://github.com/input-output-hk/cardano-node.git
cd cardano-node
git fetch --all --recurse-submodules --tags
git checkout $(curl -s https://api.github.com/repos/input-output-hk/cardano-node/releases/latest | jq -r .tag_name)

## Build options
cabal configure -O0 -w ghc-8.10.4

## Update cabal config
cabal configure -O0 -w ghc-8.10.4

# Build Cardano-node

echo "===-=====-=-==-====--===-=-====-==-=-=-=="
echo "This may take a few minutes to an hour"
echo "===-=====-=-==-====--===-=-====-==-=-=-=="
cabal build cardano-cli cardano-node

#Configure Nodes
echo "===-=====-=-==-====--===-=-====-==-=-=-=="
echo "Getting JSON files"
echo "===-=====-=-==-====--===-=-====-==-=-=-=="
mkdir $NODE_HOME
cd $NODE_HOME
wget -N https://hydra.iohk.io/build/${NODE_BUILD_NUM}/download/1/${NODE_CONFIG}-byron-genesis.json
wget -N https://hydra.iohk.io/build/${NODE_BUILD_NUM}/download/1/${NODE_CONFIG}-topology.json
wget -N https://hydra.iohk.io/build/${NODE_BUILD_NUM}/download/1/${NODE_CONFIG}-shelley-genesis.json
wget -N https://hydra.iohk.io/build/${NODE_BUILD_NUM}/download/1/${NODE_CONFIG}-config.json

#Update TraceBlockFetchDecisions to true
echo "===-=====-=-==-====--===-=-====-==-=-=-=="
echo "node config JSON traceblockfetch"
echo "===-=====-=-==-====--===-=-====-==-=-=-=="
sed -i ${NODE_CONFIG}-config.json \
    -e "s/TraceBlockFetchDecisions\": false/TraceBlockFetchDecisions\": true/g"

#Update .bashrc
echo "===-=====-=-==-====--===-=-====-==-=-=-=="
echo "Updating Bashrc"
echo "===-=====-=-==-====--===-=-====-==-=-=-=="
echo export CARDANO_NODE_SOCKET_PATH="$NODE_HOME/db/socket" >> $HOME/.bashrc
source $HOME/.bashrc


echo "===-=====-=-==-====--===-=-====-==-=-=-=="
echo "Now run the Producer or Relay Script"
echo "This depends on what node you are configuring currently"
echo "===-=====-=-==-====--===-=-====-==-=-=-=="

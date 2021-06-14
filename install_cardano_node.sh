#!/bin/bash
set -e

# Font Colors
red=`tput setaf 1`
green=`tput setaf 2`
yellow=`tput setaf 3`
cyan=`tput setaf 6`
white=`tput setaf 7`
reset=`tput sgr0`

# keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
# echo an error message before exiting
trap 'echo "${green}\"${last_command}\" command filed with exit code $?."' EXIT

# Versions
CABAL_VER="3.4.0.0"
GHC_VER="8.10.4"

  case "$1" in
    -h|--help)
      echo "=================================================="
      echo "Cardano Node Install Script"
      echo "This is designed for the initial install."
      echo "Either 1 producer & 1 relay"
      echo "or 1 producer & 2 relays"
      echo " "
      echo "options:"
      echo "-h, --help             show brief help"
      echo "-r,--relay             specify if building relay"
      echo "-p,--producer          specify if building producer"
      echo "==================================================="
      exit 0
      ;;
    -r|--relay)
      echo "You have selected \"relay\"."
      node_type="relay"
      ;;
    -p|--producer)
      echo "You have selected \"producer\"."
      node_type="producer"
      ;;
    *)
      echo "Flag arg is blank or not recognized flag."
      echo "Run script with -h || --help to get"
      echo "available options."
      exit 0
      ;;
    esac

# Choose Mainnet or Testnet deployment
echo "Is producer a testnet or mainnet deploment?: "
echo "T/t for testnet"
echo "M/m for mainnet"
read NET_choice
if [[ $NET_choice == "T" || $NET_choice == "t" ]]
    then
    echo "You selected testnet deploy..."
    NODE_NET="testnet"
elif [[ $NET_choice == "M" || $NET_choice == "m" ]]
    then
    echo "You selected mainnet deploy..."
    NODE_NET="mainnet"
else
    echo "option ${NODE_choice} is incorrect or blank"
    echo "killing script..."
    exit 0
fi
# 
# Add IP for selected choice
if [[ $node_type == "producer" ]]
    then
        echo "Do you have 0, 1 or 2 relays?"
        read count
    if [[ $count == 1 ]]
        then
        echo "What is the IP of you relay?: "
        read node_IP
    elif [[ $count == 2 ]]
        then
        echo "Enter IP of first relay?: "
        read node_IP
        echo "Enter IP of second relay?: "
        read node_second_IP
    else
        echo "Script only supports 0, 1 or 2 as options."
        echo "Please open issue for feature request or improvements: "
        echo "https://github.com/lowkeyshift/staker-3000/issues/new"
        exit 0
    fi
else
    echo "What is your producer node's IP?: "
    read node_IP
fi

# Dependencies
echo "===-=====-=-==-====--===-=-====-==-=-=-=="
echo "${red}Starting ${node_type} install."
echo "Installing dependancies"
echo "===-=====-=-==-====--===-=-====-==-=-=-=="
sudo apt-get update -y && 
sudo apt update -y && \
sudo apt-get upgrade -y && \
sudo apt install git jq bc
sudo apt-get install make automake rsync htop curl build-essential pkg-config libffi-dev libgmp-dev libssl-dev libtinfo-dev libsystemd-dev zlib1g-dev make g++ wget libncursesw5 libtool autoconf -y

# Install libsodium
echo "===-=====-=-==-====--===-=-====-==-=-=-=="
echo "${green}Installing libsodium"
echo "===-=====-=-==-====--===-=-====-==-=-=-=="
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

# Install GHCUP
echo "===-=====-=-==-====--===-=-====-==-=-=-=="
echo "${cyan}Installing GHCUP Haskell"
echo "===-=====-=-==-====--===-=-====-==-=-=-=="

echo "Answer N: when asked to installing haskell-language-server (HLS)."
echo "Answer Y: Do you want to install stack now?"
echo "Answer Y: To automatically add the required PATH variable to ".bashrc"."
read -p "Press enter to continue"

curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh

# Will need version to be updated
cd $HOME
source .bashrc
ghcup upgrade
ghcup install cabal $CABAL_VER
ghcup set cabal $CABAL_VER

ghcup install ghc $GHC_VER
ghcup set ghc $GHC_VER

#Cluster Configuration
echo "===-=====-=-==-====--===-=-====-==-=-=-=="
echo "${yellow}Exporting PATHs for iohk-nix"
echo "===-=====-=-==-====--===-=-====-==-=-=-=="

echo PATH="$HOME/.local/bin:$PATH" >> $HOME/.bashrc
echo export LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH" >> $HOME/.bashrc
echo export NODE_HOME=$HOME/cardano-my-node >> $HOME/.bashrc
echo export NODE_CONFIG=$NODE_NET >> $HOME/.bashrc
echo export NODE_BUILD_NUM=$(curl https://hydra.iohk.io/job/Cardano/iohk-nix/cardano-deployment/latest-finished/download/1/index.html | grep -e "build" | sed 's/.*build\/\([0-9]*\)\/download.*/\1/g') >> $HOME/.bashrc
source $HOME/.bashrc

#Print out version
echo "===-=====-=-==-====--===-=-====-==-=-=-=="
echo "${red}Checking Versions"
cabal update
cabal --version
ghc --version
echo "===-=====-=-==-====--===-=-====-==-=-=-=="

# Download Source code and switch to latest tag
echo "===-=====-=-==-====--===-=-====-==-=-=-=="
echo "${white}Source download Cardano-node | Tag: latest"
echo "===-=====-=-==-====--===-=-====-==-=-=-=="
cd $HOME/git
git clone https://github.com/input-output-hk/cardano-node.git
cd cardano-node
git fetch --all --recurse-submodules --tags
git checkout $(curl -s https://api.github.com/repos/input-output-hk/cardano-node/releases/latest | jq -r .tag_name)

## Update cabal config
cabal configure -O0 -w ghc-8.10.4

echo -e "package cardano-crypto-praos\n flags: -external-libsodium-vrf" > cabal.project.local
sed -i $HOME/.cabal/config -e "s/overwrite-policy:/overwrite-policy: always/g"
rm -rf $HOME/git/cardano-node/dist-newstyle/build/x86_64-linux/ghc-8.10.4

# Build Cardano-node
echo "===-=====-=-==-====--===-=-====-==-=-=-=="
echo "This may take a few minutes to an hour"
echo "===-=====-=-==-====--===-=-====-==-=-=-=="
cabal build cardano-cli cardano-node

# Copy cardano-node and cardano-cli to /bin
echo "===-=====-=-==-====--===-=-====-==-=-=-=="
echo -e "${green}Copy cardano-node and cardano-cli to /usr/local/bin/\n"
echo "===-=====-=-==-====--===-=-====-==-=-=-=="
sudo cp $(find $HOME/git/cardano-node/dist-newstyle/build -type f -name "cardano-cli") /usr/local/bin/cardano-cli
sudo cp $(find $HOME/git/cardano-node/dist-newstyle/build -type f -name "cardano-node") /usr/local/bin/cardano-node

echo "===-=====-=-==-====--===-=-====-==-=-=-=="
echo "===-=====-=-==-====--===-=-====-==-=-=-=="
echo "===-=====-=-==-====--===-=-====-==-=-=-=="
cardano-node version
cardano-cli version
echo "===-=====-=-==-====--===-=-====-==-=-=-=="
echo "===-=====-=-==-====--===-=-====-==-=-=-=="
echo "===-=====-=-==-====--===-=-====-==-=-=-=="

#Configure Nodes
echo "===-=====-=-==-====--===-=-====-==-=-=-=="
echo "${red}Getting JSON files"
echo "===-=====-=-==-====--===-=-====-==-=-=-=="
mkdir $NODE_HOME
cd $NODE_HOME
wget -N https://hydra.iohk.io/build/${NODE_BUILD_NUM}/download/1/${NODE_CONFIG}-byron-genesis.json
wget -N https://hydra.iohk.io/build/${NODE_BUILD_NUM}/download/1/${NODE_CONFIG}-topology.json
wget -N https://hydra.iohk.io/build/${NODE_BUILD_NUM}/download/1/${NODE_CONFIG}-shelley-genesis.json
wget -N https://hydra.iohk.io/build/${NODE_BUILD_NUM}/download/1/${NODE_CONFIG}-config.json

#Update TraceBlockFetchDecisions to true
echo "===-=====-=-==-====--===-=-====-==-=-=-=="
echo -e "${green}node config JSON traceblockfetch\n"
echo "===-=====-=-==-====--===-=-====-==-=-=-=="
sed -i ${NODE_CONFIG}-config.json \
    -e "s/TraceBlockFetchDecisions\": false/TraceBlockFetchDecisions\": true/g"

#Update .bashrc
echo "===-=====-=-==-====--===-=-====-==-=-=-=="
echo -e "${red}Updating Bashrc\n"
echo "===-=====-=-==-====--===-=-====-==-=-=-=="
echo export CARDANO_NODE_SOCKET_PATH="$NODE_HOME/db/socket" >> $HOME/.bashrc
source $HOME/.bashrc


echo "===-=====-=-==-====--===-=-====-==-=-=-=="
echo "Now  we run the Producer or Relay Script"
echo "This depends on what node you are configuring currently"
echo "===-=====-=-==-====--===-=-====-==-=-=-=="

if [[ $node_type == "producer" ]] & [[ $count == 1 ]]
    then
    ./block_relay.sh $node_IP
elif [ $node_type == "producer" ]] & [[ $count == 2 ]]
    then
    ./two_block_relay.sh $node_IP $node_second_IP
elif [[ $node_type == "relay" ]]
    then
    ./block_producer.sh $node_IP
else
    echo "\"${node_type} doesn't match relay||producer.\""
fi

echo "===-=====-=-==-====--===-=-====-==-=-=-=="
echo "===-=====-=-==-====--===-=-====-==-=-=-=="
echo "Install and setup complete"
echo "===-=====-=-==-====--===-=-====-==-=-=-=="
echo "To start your ${node_type} run the following command: "
echo -e "${green}sudo systemctl start cardano-node\n"
echo "===-=====-=-==-====--===-=-====-==-=-=-=="
echo -e "${red} contiue the install process by deploying your air-gapped offline machine"
echo "Script was built using this documentation: "
echo "https://www.coincashew.com/coins/overview-ada/guide-how-to-build-a-haskell-stakepool-node#6-configure-the-air-gapped-offline-machine"
echo "===-=====-=-==-====--===-=-====-==-=-=-=="
echo "You are this close."
echo "                         .aggggga,,.
                            ,d888888888888888888888888888888888888888888888888888888P""""a,
                           d8""                                                    `""""""8
                         ,8"           ,_                 a,         .a ......:::::::::;dP'
                        ,8";            8b              ..)8 ;;;;;;;;;)b;;;;;;;;;;;amd8"'
                        8';.             88,    ...::::::;;8bagmgggg8888888PPPP"""''
                       ]8;:    8b        ."888888888888888888""""        ..,aaaa,,.
                      ,8';.     8b   .::::;88";;;;;d8";:;:88'       ,add88PPPPPPPP888baaa.
                      dP;:.      "8;;;;;;a888a;aadP':;:;:8P     ,a8PPP""                ""8
                     ]8;::.       "8a;;d8888888"';;:;:;a8"  ,ad8P"         .:.:,888888888 8)
                    ,8";:.          "88';:;"PPP8b;;;;;88,ad8P'     ,a  I.:.:.:(8'......`8 88
                    dP;::.            "Pba;;::::)8b:d88P"'         8 :(I:.:.:.(8::::::::8,8)
                   (8;::..                `""P88PP""            .: 8,.(8.:.,add88888888888"
                  ,8";:.:.                                  ..::.::"ga88888PP""'''
                 .8";:.:..                              ..::.:,add8PP''
                .88;::::..                           .:.:;aad8P"''
               .88;;:.:..                        ..:.:;adP"'
              .88;;::.:..                     ...:.:;dP"
             .88;;:.::..                   ...:.::;d8"
            .88;;:.:.:..                 ...:.:.;d8"
           .88;;:.::.:.                ...:.::.;d8
          .88;;:.::.:..              ...:.:.;;d8"
         .88;;:.:.:.:..            ...:.::.;;88
        ,88;;:.:.:.:...          ...:.::.:;;88
       d8';;:.::.::.....       ....:.::.:;;88
      88;;::.::.::........   ..:.::.::.;;d88
    .8P;;::.::.:............:.:.:.::;;a88P"
   dP';;::.:.:.............:..:.:;;ad8P"
 .8P;;:.:.::..............:.:.:;d88P"
,88;;.:.::................:.:;d8"
88;;.:.:................:.:;d8P
     '':::::...........:.;d8P
           '':::::....:.;d8"
                  '':::;d8'
                     ':;8'"

exit 0

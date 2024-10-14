#!/usr/bin/env bash

read -r -p "Are you sure you want to delete all local testnet chainstate data (Y/n)? " response

if [ "${response}" == "Y" ]; then
    echo "Deleting docker compose volumes"
    docker compose down --volumes --remove-orphans --timeout=1 --rmi=all

    echo "Deleting chainstate contents"
    rm -rf chainstate/bitcoin/* chainstate/bitcoin/.*
    rm -rf chainstate/stacks-miner/* chainstate/stacks-miner/.*
    rm -rf chainstate/stacks-signer/* chainstate/stacks-signer/.*
fi

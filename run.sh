#!/usr/bin/env bash

export DOCKER_CLI_HINTS=false

# Check if stx-cli is installed
if ! command -v stx >/dev/null; then
    echo "Stacks CLI is not installed"
    echo "It can be installed via 'npm install -g @stacks/cli'"
    # exit 1
fi

# Check if miner keychain exists
if [ ! -f keychains/miner.yaml ]; then
    echo "Miner keychain not found. Generating and saving to keychains dir..."
    stx make_keychain -I "https://api.testnet.hiro.so" -H "https://api.testnet.hiro.so" -t | jq > keychains/miner.yaml

    export STACKS_MINER_PRIV_KEY="$(cat keychains/miner.yaml | jq -r '.keyInfo.privateKey')"
    STACKS_MINER_BTC_ADDR="$(cat keychains/miner.yaml | jq -r '.keyInfo.btcAddress')"

    # Render miner config toml
    envsubst < configs/stacks-miner.toml.in > configs/stacks-miner.toml

    # Import BTC address to bitcoind for stacks miner to operate correctly
    echo "Importing BTC address to bitcoind"
    docker compose up bitcoind -d
    docker exec -t stacks-testnet-env-bitcoind-1 bitcoin-cli -regtest -rpcwait -rpcuser=btc -rpcpassword=btc -named createwallet wallet_name="stacks-miner-wallet" descriptors=false load_on_startup=true
    docker exec -t stacks-testnet-env-bitcoind-1 bitcoin-cli -regtest -rpcwait -rpcuser=btc -rpcpassword=btc -named -rpcwallet=stacks-miner-wallet importaddress address="${STACKS_MINER_BTC_ADDR}"
    AVAILABLE_BTC=$(docker exec -t stacks-testnet-env-bitcoind-1 bitcoin-cli -regtest -rpcuser=btc -rpcpassword=btc getbalances | jq -r '.watchonly.trusted')

    # Check for funds
    # TODO: once Hiro's API BTC faucet is working, incorporate it into script
    if [ "${AVAILABLE_BTC}" -eq "0" ]; then
        echo "Not enough funds in BTC address ${STACKS_MINER_BTC_ADDR}"
        echo "Rerun this script once it has some funds"
        exit 1
    fi
fi

# Check if signer keychain exists
if [ ! -f keychains/signer.yaml ]; then
    echo "Signer keychain not found. Generating and saving to keychains dir..."
    stx make_keychain -I "https://api.testnet.hiro.so" -H "https://api.testnet.hiro.so" -t | jq > keychains/signer.yaml

    export STACKS_SIGNER_PRIV_KEY="$(cat keychains/signer.yaml | jq -r '.keyInfo.privateKey')"

    # Render signer config toml
    envsubst < configs/stacks-signer.toml.in > configs/stacks-signer.toml

    # Request STX to stack
    echo "Requesting STX from faucet to stack on signer address"
    STACKS_SIGNER_STX_ADDR="$(cat keychains/signer.yaml | jq -r '.keyInfo.address')"
    curl -X POST "https://api.testnet.hiro.so/extended/v1/faucets/stx?address=${STACKS_SIGNER_STX_ADDR}&stacking=true"
fi

echo "Starting all services"
docker compose up -d
# docker compose down --volumes --remove-orphans --timeout=1 --rmi=all
# # docker compose up --build
# docker compose up --build --exit-code-from monitor
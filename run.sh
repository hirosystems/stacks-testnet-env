#!/usr/bin/env bash

export DOCKER_CLI_HINTS=false

# Check if stx-cli is installed
if ! command -v stx >/dev/null; then
    echo "Stacks CLI is not installed"
    echo "It can be installed via 'npm install -g @stacks/cli'"
    exit 1
fi

# Generate miner keychain if it does not exist
if [ ! -f keychains/miner.yaml ]; then
    echo "Miner keychain not found. Generating and saving to keychains dir..."
    stx make_keychain -I "https://api.testnet.hiro.so" -H "https://api.testnet.hiro.so" -t | jq > keychains/miner.yaml
fi

export STACKS_MINER_PRIV_KEY="$(cat keychains/miner.yaml | jq -r '.keyInfo.privateKey')"
STACKS_MINER_BTC_ADDR="$(cat keychains/miner.yaml | jq -r '.keyInfo.btcAddress')"

# Render miner config toml
envsubst < configs/stacks-miner.toml.in > configs/stacks-miner.toml

# Check if bitcoind wallet was already created
docker compose up bitcoind -d
BITCOIN_WALLET_NAME="$(docker exec -t stacks-testnet-env-bitcoind-1 bitcoin-cli -regtest -rpcwait -rpcuser=btc -rpcpassword=btc -named getwalletinfo | jq -r '.walletname')"

# Import BTC address to bitcoind for stacks miner to operate correctly
if [ "${BITCOIN_WALLET_NAME}" != "stacks-miner-wallet" ]; then
    echo "Importing BTC address to bitcoind"
    docker exec -t stacks-testnet-env-bitcoind-1 bitcoin-cli -regtest -rpcwait -rpcuser=btc -rpcpassword=btc -named createwallet wallet_name="stacks-miner-wallet" descriptors=false load_on_startup=true
    docker exec -t stacks-testnet-env-bitcoind-1 bitcoin-cli -regtest -rpcwait -rpcuser=btc -rpcpassword=btc -named -rpcwallet=stacks-miner-wallet importaddress address="${STACKS_MINER_BTC_ADDR}"
fi
AVAILABLE_BTC=$(docker exec -t stacks-testnet-env-bitcoind-1 bitcoin-cli -regtest -rpcuser=btc -rpcpassword=btc getbalances | jq -r '.watchonly.trusted' + .watchonly.untrusted_pending)

# Check for funds
# TODO: once Hiro's API BTC faucet is working, incorporate it into script
if [ ${AVAILABLE_BTC} -eq 0 ]; then
    echo "Not enough funds in BTC address ${STACKS_MINER_BTC_ADDR}"
    echo "Rerun this script once it has some funds"
    exit 1
fi

# Generate signer keychain if it does not exist
if [ ! -f keychains/signer.yaml ]; then
    echo "Signer keychain not found. Generating and saving to keychains dir..."
    stx make_keychain -I "https://api.testnet.hiro.so" -H "https://api.testnet.hiro.so" -t | jq > keychains/signer.yaml
fi

export STACKS_SIGNER_PRIV_KEY="$(cat keychains/signer.yaml | jq -r '.keyInfo.privateKey')"

# Render signer config toml
envsubst < configs/stacks-signer.toml.in > configs/stacks-signer.toml

STACKS_SIGNER_STX_ADDR="$(cat keychains/signer.yaml | jq -r '.keyInfo.address')"
STACKS_SIGNER_STX_BALANCE=$(curl -s https://api.testnet.hiro.so/extended/v1/address/${STACKS_SIGNER_STX_ADDR}/balances | jq -r '.stx.balance')
STACKING_MIN_USTX=$(curl -s https://api.testnet.hiro.so/v2/pox | jq -r '.next_cycle.min_threshold_ustx')
# Bump min threshold by 50% to avoid getting stuck if threshold increases
STACKS_SIGNER_STX_THRESHOLD=$(echo "${STACKS_SIGNER_STX_BALANCE} * 1.5/1" | bc)

# Request STX to stack
if [ "${STACKS_SIGNER_STX_THRESHOLD}" -le "${STACKING_MIN_USTX}" ]; then
    echo "Requesting STX from faucet to stack on signer address"
    curl -X POST "https://api.testnet.hiro.so/extended/v1/faucets/stx?address=${STACKS_SIGNER_STX_ADDR}&stacking=true"
fi

echo "Starting all services"
STACKING_KEYS="${STACKS_SIGNER_PRIV_KEY}" docker compose up -d
# docker compose down --volumes --remove-orphans --timeout=1 --rmi=all
# # docker compose up --build
# docker compose up --build --exit-code-from monitor
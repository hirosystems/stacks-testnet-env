# Stacks Testnet Environment

Easily run a Stacks miner in Kypton mode with a signer and Bitcoind testnet instance

# Getting Started

1. Make sure you have Docker and Docker Compose installed and running on your machine.
1. If you already have a generated keychain for the miner and/or the signer, place them in the `keychains` dir in separate YAML files named `miner.yaml` and `signer.yaml`.
1. If you already have chainstate data for bitcoind, stacks core, or the stacks signer, place them in their respective dirs within `chainstate`.

Then run:

```bash
./run.sh
```

This will generate a new set of miner and signer STX/BTC keys if needed, generate miner and signer configs, check the balances of all relevant addresses, assist in funding them if needed, and start all services.

This will output the logs from each service. You can view the logs for a single service with:

```
docker-compose logs <SERVICE NAME>
```

Add `-f` to automatically follow new logs. The service names can be found in [./docker-compose.yml](./docker-compose.yml), such as `stacks-node`, `signer`, and `monitor`.

### Shutdown

```bash
./stop.sh
```

### Reset

Warning: Running this script will wipe all local chainstate data, requiring you to re-sync your bitcoin and stacks nodes to chaintip the next time they're booted up.

```bash
./reset.sh
```

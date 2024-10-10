# Stacks Testnet Environment

Easily run a Stacks miner in Kypton mode with a signer and Bitcoind testnet instance

# Getting Started
Generate a new testnet keychain via the Stacks CLI

```bash
stx make_keychain -I "https://api.testnet.hiro.so" -H "https://api.testnet.hiro.so" -t
```
Replace all instances of `<MINER_SEED>` in /configs/stacks-miner.toml

Make sure you have Docker and Docker Compose installed and running on your machine, then run:

```bash
./run.sh
```

This will output the logs from each service. You can view the logs for a single service with:

```
docker-compose logs $service_name
```

Add `-f` to automatically follow new logs. The service names can be found in [./docker-compose.yml](./docker-compose.yml), such as `stacks-node`, `signer`, and `monitor`.

### Shutdown

```shell
./stop.sh
```

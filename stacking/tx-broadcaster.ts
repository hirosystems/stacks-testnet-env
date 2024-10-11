import { StacksTestnet } from '@stacks/network';
import { StackingClient } from '@stacks/stacking';
import {
  TransactionVersion,
  getAddressFromPrivateKey,
  getNonce,
  makeSTXTokenTransfer,
  broadcastTransaction,
  StacksTransaction,
} from '@stacks/transactions';
import { logger } from './common';

const broadcastInterval = parseInt(process.env.NAKAMOTO_BLOCK_INTERVAL ?? '2');
const url = `http://${process.env.STACKS_CORE_RPC_HOST}:${process.env.STACKS_CORE_RPC_PORT}`;
const network = new StacksTestnet({ url });

const accounts = process.env.ACCOUNT_KEYS!.split(',').map(privKey => ({
  privKey,
  stxAddress: getAddressFromPrivateKey(privKey, TransactionVersion.Testnet),
}));

const client = new StackingClient(accounts[0].stxAddress, network);

async function run() {
  const accountNonces = await Promise.all(
    accounts.map(async account => {
      const nonce = await getNonce(account.stxAddress, network);
      return { ...account, nonce };
    })
  );

  // Send from account with lowest nonce
  accountNonces.sort((a, b) => Number(a.nonce) - Number(b.nonce));
  const sender = accountNonces[0];
  const recipient = accountNonces[1];

  logger.info(
    `Sending stx-transfer from ${sender.stxAddress} (nonce=${sender.nonce}) to ${recipient.stxAddress}`
  );

  const tx = await makeSTXTokenTransfer({
    recipient: recipient.stxAddress,
    amount: 1000,
    senderKey: sender.privKey,
    network,
    nonce: sender.nonce,
    fee: 300,
    anchorMode: 'any',
  });
  await broadcast(tx, sender.stxAddress);
}

async function broadcast(tx: StacksTransaction, sender?: string) {
  const txType = tx.payload.payloadType;
  const label = sender ? accountLabel(sender) : 'Unknown';
  const broadcastResult = await broadcastTransaction(tx, network);
  if (broadcastResult.error) {
    logger.error({ ...broadcastResult, account: label }, `Error broadcasting ${txType}`);
    return false;
  } else {
    if (label.includes('Flooder')) return true;
    logger.debug(`Broadcast ${txType} from ${label} tx=${broadcastResult.txid}`);
    return true;
  }
}

function accountLabel(address: string) {
  const accountIndex = accounts.findIndex(account => account.stxAddress === address);
  if (accountIndex !== -1) {
    return `Account #${accountIndex}`;
  }
  return `Unknown (${address})`;
}

async function loop() {
  while (true) {
    try {
      await run();
    } catch (e) {
      logger.error(e, 'Error in tx-broadcaster loop');
    }
    await new Promise(resolve => setTimeout(resolve, broadcastInterval * 1000));
  }
}
loop();

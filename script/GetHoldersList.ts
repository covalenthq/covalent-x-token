import { writeFileSync, existsSync, mkdirSync } from 'fs';
import { join } from 'path';

import dotenv from 'dotenv';

import { JsonRpcProvider } from "ethers";

import { abi as ERC20ABI } from '../out/ERC20.sol/ERC20.json';
import getContractInstance from './utils/getContractInstance';
import { ERC20 } from "../out/types";

dotenv.config();

const GetHoldersList = async () => {
    if (!process.env.RPC) {
        throw new Error('RPC is required');
    }

    const transferToken = process.env.CQT || "0xD417144312DbF50465b1C641d016962017Ef6240";

    const provider = new JsonRpcProvider(process.env.RPC);
    const network = await provider.getNetwork()
        .catch(() => null);
    if (!network?.chainId) {
        throw new Error('invalid Json RPC!');
    }

    const tokenCode = await provider.getCode(transferToken)
        .catch(() => null);
    console.log('Token address: ', transferToken);
    if (tokenCode === '0x' || !tokenCode) {
        throw new Error('invalid token address');
    }

    const tokenContract = getContractInstance<ERC20>(
        transferToken,
        ERC20ABI,
        provider,
    );

    const isStaticFileDirExists = existsSync(join(__dirname, 'staticFiles'))
    if (!isStaticFileDirExists) {
        mkdirSync(join(__dirname, 'staticFiles'))
    }

    let currentFromBlock = 12474448;
    const latestBlock = await provider.getBlockNumber();

    let transferEvents = await tokenContract.queryFilter(
        tokenContract.filters.Transfer,
        currentFromBlock,
        currentFromBlock + 9999
    );


    while (currentFromBlock < latestBlock) {
        currentFromBlock += 10000;
        console.log(`fetching block: ${currentFromBlock}`);

        let toBlock = currentFromBlock + 9999;
        if (toBlock > latestBlock) {
            toBlock = latestBlock;
        }

        transferEvents = transferEvents.concat(await tokenContract.queryFilter(
            tokenContract.filters.Transfer,
            currentFromBlock,
            toBlock
        ));

    }

    const holders: { [p: string]: bigint } = {};

    transferEvents.forEach((te) => {
        if (!holders[te.args.from]) {
            holders[te.args.from] = BigInt(0);
        }
        if (!holders[te.args.to]) {
            holders[te.args.to] = BigInt(0);
        }
        holders[te.args.from] -= te.args.value;
        holders[te.args.to] += te.args.value;
    });

    writeFileSync(
        join(__dirname, 'staticFiles', 'holders.json'),
        JSON.stringify(
            Object.fromEntries(
                Object.entries(holders)
                    .map(([address, balance]) => [address, balance.toString()])
            )
        )
    );
}

GetHoldersList()
    .then(() => {
        console.log('Holders list stored in holders.json!!');
    })
    .catch((error) => {
        console.error('error while batch transfer of balances to holders: ', error);
        process.exitCode = 1;
    })
    .finally(process.exit);

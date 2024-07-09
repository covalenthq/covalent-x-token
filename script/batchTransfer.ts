import dotenv from 'dotenv';
import { JsonRpcProvider, Wallet, parseUnits } from 'ethers';

import { abi as CovalentMigrationABI } from '../out/CovalentMigration.sol/CovalentMigration.json';
import { abi as ERC20ABI } from '../out/ERC20.sol/ERC20.json';
import getContractInstance from './utils/getContractInstance';
import Holders from './staticFiles/holders.json';
import { CovalentMigration, ERC20 } from '../out/types';

dotenv.config();

const BatchTransfer = async () => {
	// Note: Check addresses and ignoreAmount before running the script
	// Script won't distribute to these addresses and below ignoreAmount.
	const ignoreAddresses = ['0xb270fc573f9f9868ab11b52ae7119120f6a4471d', '0x6af3d183d225725d975c5eaa08d442dd01aad8ff'];
	const ignoreAmount = parseUnits('5000', 18);

	if (!process.env.PRIVATE_KEY) {
		throw new Error('PRIVATE_KEY is required');
	}
	if (!process.env.RPC) {
		throw new Error('RPC is required');
	}
	if (!process.env.MIGRATION_CONTRACT_ADDRESS) {
		throw new Error('MIGRATION_CONTRACT_ADDRESS is required');
	}

	const provider = new JsonRpcProvider(process.env.RPC);
	const network = await provider.getNetwork()
		.catch(() => null);
	if (!network?.chainId) {
		throw new Error('invalid Json RPC!');
	}

	const signer = new Wallet(process.env.PRIVATE_KEY, provider);
	const signerAddress = await signer.getAddress()
		.catch(() => null);
	if (!signerAddress) {
		throw new Error('invalid private key!');
	}

	const migrationContractAddress = process.env.MIGRATION_CONTRACT_ADDRESS;
	const covalentMigrationContract = getContractInstance<CovalentMigration>(
		migrationContractAddress,
		CovalentMigrationABI,
		provider,
	);
	const tokenAddress = await covalentMigrationContract.cxt()
		.catch(() => null);

	if (!tokenAddress) {
		throw new Error('invalid migration contract address!');
	}

	const tokenContract = getContractInstance<ERC20>(
		tokenAddress,
		ERC20ABI,
		provider,
	);


	const holderEntries = Object.entries(Holders).filter(([address, balance]) => BigInt(balance) > ignoreAmount && !ignoreAddresses.includes(address));

	let startIndex = 0;
	while (holderEntries.slice(startIndex, startIndex + 1050).length > 0) {
		const slicedData = holderEntries.slice(startIndex, startIndex + 1050);

		if (slicedData.length > 0) {
			// this is only for estimation change it .batchDistribute(address[], uint256[]) to distribute the tokens
			const remainingBalance = await tokenContract.balanceOf(migrationContractAddress);
			const amountOfThisBatch = slicedData
				.reduce((prev, [, balance]) => prev + BigInt(balance), BigInt(0))
			console.log(`distributing total amount in this batch ${Math.round(startIndex / 1050)
				}: ${amountOfThisBatch.toString()}`)
			console.log(`remaining balance: ${remainingBalance.toString()}`)
			if (amountOfThisBatch <= remainingBalance) {
				const estimatedGas = await covalentMigrationContract.connect(signer)
					.batchDistribute
					.estimateGas(
						slicedData.map(([address]) => address),
						slicedData.map(([, balance]) => BigInt(balance))
					);
				console.log(`estimated gas for batch ${Math.round(startIndex / 1050)
					}: ${estimatedGas.toString()}`)
				const tx = await covalentMigrationContract.connect(signer)
					.batchDistribute(
						slicedData.map(([address]) => address),
						slicedData.map(([, balance]) => BigInt(balance))
					);
				await tx.wait();
			}
		}
		startIndex += 1050;
	}
}

BatchTransfer()
	.then(() => {
		console.log('Distribution complete!!');
	})
	.catch((error) => {
		console.error('error while distribution of token to holders: ', error);
		process.exitCode = 1;
	})
	.finally(process.exit);

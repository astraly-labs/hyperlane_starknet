import {
    Account,
    RpcProvider,
} from "starknet";

import dotenv from "dotenv";

dotenv.config();


const ACCOUNT_ADDRESS = process.env.ACCOUNT_ADDRESS;
const PRIVATE_KEY = process.env.PRIVATE_KEY;

export async function buildAccount(): Promise<Account> {
    const provider = new RpcProvider({ nodeUrl: process.env.STARKNET_RPC_URL });

    if (!PRIVATE_KEY || !ACCOUNT_ADDRESS) {
        throw new Error("Private key or account address not set in .env file");
    }

    return new Account(provider, ACCOUNT_ADDRESS, PRIVATE_KEY);
}
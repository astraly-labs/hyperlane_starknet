import { Contract } from "starknet";
import { buildAccount } from "./utils";
import { getDeployedAddress } from "./deployments";
import dotenv from "dotenv";

dotenv.config();

const NETWORK = process.env.NETWORK;
const DEFAULT_HOOK = "0x3531fcf312035d230bc0e68fc0198457f44a82d0f1f67f418b227b80788a390";
const REQUIRED_HOOK = "0x3531fcf312035d230bc0e68fc0198457f44a82d0f1f67f418b227b80788a390";

async function updateHooks(): Promise<void> {
    try {
        if (!NETWORK) {
            throw new Error('NETWORK environment variable is not set');
        }

        const account = await buildAccount();

        const mailboxAddress = getDeployedAddress(NETWORK, 'mailbox');
        const { abi } = await account.getClassAt(mailboxAddress);
        const mailboxContract = new Contract(abi, mailboxAddress, account);

        if (DEFAULT_HOOK != undefined) {
            console.log(`🧩 Updating default hook ${DEFAULT_HOOK}..`);
            const invoke = await mailboxContract.invoke("set_default_hook", [DEFAULT_HOOK])
            await account.waitForTransaction(invoke.transaction_hash);

            console.log(`⚡️ Transaction hash: ${invoke.transaction_hash}`);
        }

        if (REQUIRED_HOOK != undefined) {
            console.log(`🧩 Updating required hook ${REQUIRED_HOOK}..`);
            const invoke = await mailboxContract.invoke("set_required_hook", [REQUIRED_HOOK])
            await account.waitForTransaction(invoke.transaction_hash);

            console.log(`⚡️ Transaction hash: ${invoke.transaction_hash}`);
        }

        console.log(`🧩 Hooks updated successfully with ${DEFAULT_HOOK} & ${REQUIRED_HOOK}`);
    } catch (error) {
        console.error(`⛔ Error updating hooks ${DEFAULT_HOOK} & ${REQUIRED_HOOK}:`, error);
    }
}

updateHooks().then(() => {
    console.log('Hooks updated successfully');
}
).catch((error) => {
    console.error('Error updating hooks:', error);
}
);
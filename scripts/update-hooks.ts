import { Contract } from "starknet";
import { buildAccount } from "./utils";
import { getDeployedAddress } from "./deployments";
import dotenv from "dotenv";

dotenv.config();

const NETWORK = process.env.NETWORK;
const DEFAULT_HOOK = "0x2a155aac0327e9a2e84052615577c62f4059245008efa4a7b07fa0dedfa1cb5";
const REQUIRED_HOOK = "0x2a155aac0327e9a2e84052615577c62f4059245008efa4a7b07fa0dedfa1cb5";

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
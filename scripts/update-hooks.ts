import { Contract } from "starknet";
import { buildAccount } from "./utils";
import { getDeployedAddress } from "./deployments";
import dotenv from "dotenv";
import { Command } from "commander";

dotenv.config();

// Initialize commander
const program = new Command();

program
    .option('-n, --network <network>', 'Network environment (e.g., mainnet, testnet)', process.env.NETWORK)
    .option('-d, --defaultHook <defaultHook>', 'Default hook address (optional)', undefined)
    .option('-r, --requiredHook <requiredHook>', 'Required hook address')
    .parse(process.argv);

const options = program.opts();

const NETWORK = options.network;
const DEFAULT_HOOK = options.defaultHook;
const REQUIRED_HOOK = options.requiredHook;

if (!NETWORK) {
    console.error('⛔ Error: Network argument is required.');
    process.exit(1);
}

if (!REQUIRED_HOOK) {
    console.error('⛔ Error: Required hook argument is required.');
    process.exit(1);
}

async function updateHooks(): Promise<void> {
    try {
        const account = await buildAccount();

        const mailboxAddress = getDeployedAddress(NETWORK, 'mailbox');
        const { abi } = await account.getClassAt(mailboxAddress);
        const mailboxContract = new Contract(abi, mailboxAddress, account);

        if (DEFAULT_HOOK != undefined) {
            console.log(`🧩 Updating default hook ${DEFAULT_HOOK}..`);
            const invoke = await mailboxContract.invoke("set_default_hook", [DEFAULT_HOOK]);
            await account.waitForTransaction(invoke.transaction_hash);

            console.log(`⚡️ Transaction hash: ${invoke.transaction_hash}`);
        }

        if (REQUIRED_HOOK != undefined) {
            console.log(`🧩 Updating required hook ${REQUIRED_HOOK}..`);
            const invoke = await mailboxContract.invoke("set_required_hook", [REQUIRED_HOOK]);
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
}).catch((error) => {
    console.error('Error updating hooks:', error);
});


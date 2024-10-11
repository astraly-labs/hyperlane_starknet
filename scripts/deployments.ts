import fs from "fs";
import path from "path";

interface ContractAddresses {
    [key: string]: string | object;
}

export function getDeployedAddress(
    chainName: string,
    contractName: string,
): string {
    try {
        const filePath = path.join(
            __dirname,
            "deployments",
            chainName,
            "deployments.json",
        );
        const fileContents = fs.readFileSync(filePath, "utf8");
        const config: ContractAddresses = JSON.parse(fileContents);

        let address: string | undefined;

        // Handle nested structures
        const findAddress = (obj: any, key: string): string | undefined => {
            if (obj[key] && typeof obj[key] === "string") {
                return obj[key] as string;
            }
            for (const k in obj) {
                if (typeof obj[k] === "object") {
                    const found = findAddress(obj[k], key);
                    if (found) return found;
                }
            }
            return undefined;
        };

        address = findAddress(config, contractName);

        if (!address) {
            throw new Error(
                `Invalid or missing address for contract ${contractName} in deployments.json for chain ${chainName}`,
            );
        }

        return address;
    } catch (error) {
        console.error(
            `Error reading configuration file for chain ${chainName}:`,
            error,
        );
        throw error;
    }
}

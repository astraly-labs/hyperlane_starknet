import {
  Account,
  Contract,
  json,
  Provider,
  CallData,
  RpcProvider,
  ContractFactory, 
  ContractFactoryParams
} from "starknet";
import fs from "fs";
import path from "path";
import dotenv from "dotenv";

dotenv.config();

const BUILD_PATH = "../cairo/target/dev/hyperlane_starknet";
const ACCOUNT_ADDRESS = process.env.ACCOUNT_ADDRESS;
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const CONFIG_FILE = "contract_config.json";
const NETWORK = process.env.NETWORK
const DEPLOYED_CONTRACTS_FILE = path.join('deployments', `${NETWORK}_deployed_contracts.json`);


interface DeployedContracts {
  [key: string]: string;
}

interface ContractConfig {
  name: string;
  constructor: Record<string, { type: string; value: string | string[] }>;
}

interface Config {
  contracts: Record<string, ContractConfig>;
  deploymentOrder: string[];
}

async function buildAccount(): Promise<Account> {
  const provider = new RpcProvider({ nodeUrl: process.env.STARKNET_RPC_URL });

  if (!PRIVATE_KEY || !ACCOUNT_ADDRESS) {
    throw new Error("Private key or account address not set in .env file");
  }
  if (!NETWORK) {
    throw new Error('NETWORK environment variable is not set');
  }

  return new Account(provider, ACCOUNT_ADDRESS, PRIVATE_KEY);
}

function getCompiledContract(name: string): any {
  const contractPath = `${BUILD_PATH}_${name}.contract_class.json`;
  return json.parse(fs.readFileSync(contractPath).toString("ascii"));
}

function getCompiledContractCasm(name: string): any {
  const contractPath = `${BUILD_PATH}_${name}.compiled_contract_class.json`;
  return json.parse(fs.readFileSync(contractPath).toString("ascii"));
}

function processConstructorArgs(args: Record<string, { type: string; value: string | string[] }>, deployedContracts: DeployedContracts): any {
  return Object.entries(args).reduce((acc, [key, { type, value }]) => {
    if (typeof value === 'string' && value.startsWith('$')) {
      if (value === '$OWNER_ADDRESS') {
        acc[key] = ACCOUNT_ADDRESS;
      } else if (value === '$BENEFICIARY_ADDRESS') {
        acc[key] = process.env.BENEFICIARY_ADDRESS;
      } else {
        const contractName = value.slice(1);
        if (deployedContracts[contractName]) {
          acc[key] = deployedContracts[contractName];
        } else {
          throw new Error(`Contract ${contractName} not yet deployed, required for ${key}`);
        }
      }
    } else {
      acc[key] = value;
    }
    return acc;
  }, {} as any);
}

async function deployContract(
  account: Account,
  contractName: string,
  constructorArgs: ContractConfig['constructor'],
  deployedContracts: DeployedContracts
): Promise<string> {
  console.log(`Deploying contract ${contractName}...`);
  
  const compiledContract = getCompiledContract(contractName);
  const casm = getCompiledContractCasm(contractName);
  const processedArgs = processConstructorArgs(constructorArgs, deployedContracts);
  const constructorCalldata = CallData.compile(processedArgs);
  const params: ContractFactoryParams = {
    compiledContract,
    account,
    casm
  };

  const contractFactory = new ContractFactory(params);  const contract = await contractFactory.deploy(constructorCalldata);

  console.log(`Contract ${contractName} deployed at address:`, contract.address);

  return contract.address;
}

async function deployContracts(): Promise<DeployedContracts> {
  try {
    const account = await buildAccount();
    const config: Config = JSON.parse(fs.readFileSync(CONFIG_FILE, 'utf-8'));
    const deployedContracts: DeployedContracts = {};

    for (const contractName of config.deploymentOrder) {
      const address = await deployContract(
        account, 
        contractName, 
        config.contracts[contractName].constructor, 
        deployedContracts
      );
      deployedContracts[contractName] = address;
    }

    console.log("All contracts deployed successfully:");
    console.log(deployedContracts);

    fs.writeFileSync(DEPLOYED_CONTRACTS_FILE, JSON.stringify(deployedContracts, null, 2));
    console.log(`Deployed contracts saved to ${DEPLOYED_CONTRACTS_FILE}`);

    return deployedContracts;
  } catch (error) {
    console.error("Deployment failed:", error);
    throw error;
  }
}

deployContracts()
  .then((addresses) => {
    console.log("Deployment successful. Contract addresses:", addresses);
  })
  .catch((error) => {
    console.error("Deployment failed:", error);
  });
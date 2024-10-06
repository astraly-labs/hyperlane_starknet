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

const BUILD_PATH = "../cairo/target/dev/contracts";
const MOCK_BUILD_PATH = "../cairo/target/dev/mocks";
const ACCOUNT_ADDRESS = process.env.ACCOUNT_ADDRESS;
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const CONFIGS_DIR = 'configs';
const DEPLOYMENTS_DIR = 'deployments';
const NETWORK = process.env.NETWORK;

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

function getConfigPath(network: string): string {
  if (!network) {
    throw new Error('NETWORK environment variable is not set');
  }

  const configFileName = `${network.toLowerCase()}.json`;
  const configPath = path.join(CONFIGS_DIR, configFileName);

  if (!fs.existsSync(configPath)) {
    throw new Error(`Config file not found for network ${network} at ${configPath}`);
  }

  return configPath;
}

function ensureNetworkDirectory(network: string): string {
  if (!network) {
    throw new Error('NETWORK environment variable is not set');
  }

  // Create main deployments directory if it doesn't exist
  if (!fs.existsSync(DEPLOYMENTS_DIR)) {
    fs.mkdirSync(DEPLOYMENTS_DIR);
  }

  // Create network-specific subdirectory
  const networkDir = path.join(DEPLOYMENTS_DIR, network);
  if (!fs.existsSync(networkDir)) {
    fs.mkdirSync(networkDir);
  }

  return networkDir;
}

function findContractFile(name: string, suffix: string): string {
  const mainPath = `${BUILD_PATH}_${name}${suffix}`;
  const mockPath = `${MOCK_BUILD_PATH}_${name}${suffix}`;

  if (fs.existsSync(mainPath)) {
    return mainPath;
  } else if (fs.existsSync(mockPath)) {
    console.log(`Using mock contract for ${name} from ${mockPath}`);
    return mockPath;
  }

  throw new Error(`Contract file not found for ${name} with suffix ${suffix} in either ${BUILD_PATH} or ${MOCK_BUILD_PATH}`);
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
  const contractPath = findContractFile(name, '.contract_class.json');
  return json.parse(fs.readFileSync(contractPath).toString("ascii"));
}

function getCompiledContractCasm(name: string): any {
  const contractPath = findContractFile(name, '.compiled_contract_class.json');
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

  const contractFactory = new ContractFactory(params);
  const contract = await contractFactory.deploy(constructorCalldata);

  console.log(`Contract ${contractName} deployed at address:`, contract.address);

  return contract.address;
}

async function deployContracts(): Promise<DeployedContracts> {
  try {
    if (!NETWORK) {
      throw new Error('NETWORK environment variable is not set');
    }

    const account = await buildAccount();

    // Get network-specific config file
    const configPath = getConfigPath(NETWORK);
    const config: Config = JSON.parse(fs.readFileSync(configPath, 'utf-8'));

    const deployedContracts: DeployedContracts = {};

    // Ensure network directory exists and set up deployment file path
    const networkDir = ensureNetworkDirectory(NETWORK);
    const deploymentsFile = path.join(networkDir, 'deployments.json');

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

    // Write deployments to network-specific file
    fs.writeFileSync(deploymentsFile, JSON.stringify(deployedContracts, null, 2));
    console.log(`Deployed contracts saved to ${deploymentsFile}`);

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
import {
  Account,
  json,
  CallData,
  ContractFactory,
  ContractFactoryParams
} from "starknet";
import fs from "fs";
import path from "path";
import dotenv from "dotenv";
import { buildAccount } from "./utils";

dotenv.config();

const BUILD_PATH = "../cairo/target/dev/contracts";
const MOCK_BUILD_PATH = "../cairo/target/dev/mocks";
const TOKEN_BUILD_PATH= "../xerc20/target/dev/xerc20"
const ACCOUNT_ADDRESS = process.env.ACCOUNT_ADDRESS;
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
  const xerc20Path = `${TOKEN_BUILD_PATH}_${name}${suffix}`;

  if (fs.existsSync(mainPath)) {
    return mainPath;
  } else if (fs.existsSync(mockPath)) {
    console.log(`Using mock contract for ${name} from ${mockPath}`);
    return mockPath;
  } else if (fs.existsSync(xerc20Path)) {
    return xerc20Path;
  }

  throw new Error(`Contract file not found for ${name} with suffix ${suffix} in either ${BUILD_PATH} or ${MOCK_BUILD_PATH}`);
}



function getCompiledContract(name: string): any {
  const contractPath = findContractFile(name, '.contract_class.json');
  return json.parse(fs.readFileSync(contractPath).toString("ascii"));
}

function getCompiledContractCasm(name: string): any {
  const contractPath = findContractFile(name, '.compiled_contract_class.json');
  return json.parse(fs.readFileSync(contractPath).toString("ascii"));
}

async function processConstructorArgs(
  args: Record<string, { type: string; value: string | string[] }>, 
  deployedContracts: DeployedContracts,
  account: Account
): Promise<any> {

  if (!ACCOUNT_ADDRESS) {
    throw new Error('ACCOUNT_ADDRESS environment variable is not set');
  }

  if (!process.env.BENEFICIARY_ADDRESS) {
    throw new Error('BENEFICIARY_ADDRESS environment variable is not set');
  }

  const processedArgs: Record<string, string | string[]> = {};
  
  for (const [key, { type, value }] of Object.entries(args)) {
    if (typeof value === 'string' && value.startsWith('$')) {
      if (value === '$OWNER_ADDRESS') {
        processedArgs[key] = ACCOUNT_ADDRESS as string;
      } else if (value === '$BENEFICIARY_ADDRESS') {
        processedArgs[key] = process.env.BENEFICIARY_ADDRESS as string;
      } else if (value === '$XERC20_CLASS_HASH') {
        const xerc20ClassHash = await declareContract(account, 'XERC20');
        processedArgs[key] = xerc20ClassHash;
      } else if (value === '$LOCKBOX_CLASS_HASH') {
        const lockboxClassHash = await declareContract(account, 'XERC20Lockbox');
        processedArgs[key] = lockboxClassHash;
      } else {
        const contractName = value.slice(1);
        if (deployedContracts[contractName]) {
          processedArgs[key] = deployedContracts[contractName];
        } else {
          throw new Error(`Contract ${contractName} not yet deployed, required for ${key}`);
        }
      }
    } else {
      processedArgs[key] = value;
    }
  }
  
  return processedArgs;
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
  const processedArgs = await processConstructorArgs(constructorArgs, deployedContracts, account);
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


async function declareContract(account: Account, name: string): Promise<string> {
  console.log(`Declaring contract ${name}...`);
  const compiledContract = getCompiledContract(name);
  const casm = getCompiledContractCasm(name);
  
  const declareResponse = await account.declareIfNot({
    contract: compiledContract,
    casm
  });

  console.log(`Contract ${name} declared with class hash:`, declareResponse.class_hash);
  
  return declareResponse.class_hash;
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
      let address = await deployContract(
        account,
        contractName,
        config.contracts[contractName].constructor,
        deployedContracts
      );

      // Ensure the address is 66 characters long (including the '0x' prefix)
      if (address.length < 66) {
        address = '0x' + address.slice(2).padStart(64, '0');
      }

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
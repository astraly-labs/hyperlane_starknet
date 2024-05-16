use std::sync::Arc;

use starknet::{
    accounts::{Account, ConnectedAccount, SingleOwnerAccount},
    contract::ContractFactory,
    core::types::{
        contract::SierraClass, BlockId, BlockTag, FieldElement, InvokeTransactionResult,
        StarknetError,
    },
    providers::{jsonrpc::HttpTransport, AnyProvider, JsonRpcClient, Provider, ProviderError, Url},
    signers::{LocalWallet, SigningKey},
};

use super::{types::Codes, StarknetAccount};

const BUILD_PATH_PREFIX: &str = "../contracts/target/dev/hyperlane_starknet_";

const KATANA_RPC_URL: &str = "http://localhost:5050";

const KATANA_PREFUNDED_ACCOUNTS: [(&str, &str); 3] = [
    (
        "0xb3ff441a68610b30fd5e2abbf3a1548eb6ba6f3559f2862bf2dc757e5828ca",
        "0x2bbf4f9fd0bbb2e60b0316c1fe0b76cf7a4d0198bd493ced9b8df2a3a24d68a",
    ),
    (
        "0xe29882a1fcba1e7e10cad46212257fea5c752a4f9b1b1ec683c503a2cf5c8a",
        "0x14d6672dcb4b77ca36a887e9a11cd9d637d5012468175829e9c6e770c61642",
    ),
    (
        "0x29873c310fbefde666dc32a1554fea6bb45eecc84f680f8a2b0a8fbb8cb89af",
        "0xc5b2fcab997346f3ea1c00b002ecf6f382c5f9c9659a3894eb783c5320f912",
    ),
];

const KATANA_CHAIN_ID: u64 = 82743958523457;

/// Returns a pre-funded account for a local katana chain.
pub fn get_dev_account(index: u32) -> StarknetAccount {
    let (address, private_key) = *KATANA_PREFUNDED_ACCOUNTS
        .get(index as usize)
        .expect("Invalid index");

    let signer = LocalWallet::from_signing_key(SigningKey::from_secret_scalar(
        FieldElement::from_hex_be(&private_key).unwrap(),
    ));

    let mut account = build_single_owner_account(
        &Url::parse(KATANA_RPC_URL).expect("Invalid rpc url"),
        signer,
        &FieldElement::from_hex_be(address).unwrap(),
        false,
        KATANA_CHAIN_ID,
    );

    // `SingleOwnerAccount` defaults to checking nonce and estimating fees against the latest
    // block. Optionally change the target block to pending with the following line:
    account.set_block_id(BlockId::Tag(BlockTag::Pending));

    account
}

/// Creates a single owner account for a given signer and account address.
///
/// # Arguments
///
/// * `rpc_url` - The rpc url of the chain.
/// * `signer` - The signer of the account.
/// * `account_address` - The address of the account.
/// * `is_legacy` - Whether the account is legacy (Cairo 0) or not.
/// * `domain_id` - The hyperlane domain id of the chain.
pub fn build_single_owner_account(
    rpc_url: &Url,
    signer: LocalWallet,
    account_address: &FieldElement,
    is_legacy: bool,
    chain_id: u64,
) -> StarknetAccount {
    let rpc_client =
        AnyProvider::JsonRpcHttp(JsonRpcClient::new(HttpTransport::new(rpc_url.clone())));

    let execution_encoding = if is_legacy {
        starknet::accounts::ExecutionEncoding::Legacy
    } else {
        starknet::accounts::ExecutionEncoding::New
    };

    SingleOwnerAccount::new(
        rpc_client,
        signer,
        *account_address,
        chain_id.into(),
        execution_encoding,
    )
}

/// Get the contract artifact from the build directory.
/// # Arguments
/// * `path` - The path to the contract artifact.
/// # Returns
/// The contract artifact.
fn contract_artifact(contract_name: &str) -> eyre::Result<SierraClass> {
    let artifact_path = format!("{BUILD_PATH_PREFIX}{contract_name}.contract_class.json");
    let file = std::fs::File::open(artifact_path).unwrap_or_else(|_| {
        panic!(
            "Compiled contract {} not found: run `scarb build` in ../contracts",
            contract_name
        )
    });
    serde_json::from_reader(file).map_err(Into::into)
}

/// Deploys a contract with the given class hash, constructor calldata, and salt.
/// Returns the deployed address and the transaction result.
pub async fn deploy_contract(
    class_hash: FieldElement,
    constructor_calldata: Vec<FieldElement>,
    salt: FieldElement,
    deployer: &StarknetAccount,
) -> (FieldElement, InvokeTransactionResult) {
    let contract_factory = ContractFactory::new(class_hash, deployer);

    let deployment = contract_factory.deploy(constructor_calldata, salt, false);

    (
        deployment.deployed_address(),
        deployment.send().await.expect("Failed to deploy contract"),
    )
}

/// Check if a contract class is already declared.
/// # Arguments
/// * `provider` - The StarkNet provider.
/// * `class_hash` - The contract class hash.
/// # Returns
/// `true` if the contract class is already declared, `false` otherwise.
async fn is_already_declared<P>(provider: &P, class_hash: &FieldElement) -> eyre::Result<bool>
where
    P: Provider,
{
    match provider
        .get_class(BlockId::Tag(BlockTag::Pending), class_hash)
        .await
    {
        Ok(_) => {
            eprintln!("Not declaring class as it's already declared. Class hash:");
            println!("{}", format!("{:#064x}", class_hash));

            Ok(true)
        }
        Err(ProviderError::StarknetError(StarknetError::ClassHashNotFound)) => Ok(false),
        Err(err) => Err(err.into()),
    }
}

/// Declare a contract class. If the contract class is already declared, do nothing.
/// # Arguments
/// * `account` - The StarkNet account.
/// * `contract_name` - The contract name.
/// # Returns
/// The contract class hash.
async fn declare_contract(
    account: &StarknetAccount,
    contract_name: &str,
) -> eyre::Result<FieldElement> {
    // Load the contract artifact.
    let contract_artifact = contract_artifact(contract_name)?;

    // Compute the contract class hash.
    let class_hash = contract_artifact.class_hash()?;

    // Declare the contract class if it is not already declared.
    if !is_already_declared(account.provider(), &class_hash).await? {
        println!("\n==> Declaring Contract: {contract_name}");
        let flattened_class = contract_artifact.flatten()?;
        account
            .declare(Arc::new(flattened_class), class_hash)
            .send()
            .await?;
        println!("Declared Class Hash: {}", format!("{:#064x}", class_hash));
    };

    Ok(class_hash)
}

pub async fn declare_all(deployer: &StarknetAccount) -> eyre::Result<Codes> {
    let mailbox = declare_contract(deployer, "mailbox").await?;
    let va = declare_contract(deployer, "validator_announce").await?;
    let ism_multisig = declare_contract(deployer, "messageid_multisig_ism").await?;
    let test_mock_ism = declare_contract(deployer, "ism").await?;
    let ism_routing = declare_contract(deployer, "domain_routing_ism").await?;

    Ok(Codes {
        mailbox,
        va,
        hook_aggregate: FieldElement::ZERO,
        hook_merkle: FieldElement::ZERO,
        hook_pausable: FieldElement::ZERO,
        hook_routing: FieldElement::ZERO,
        hook_routing_custom: FieldElement::ZERO,
        hook_routing_fallback: FieldElement::ZERO,
        igp: FieldElement::ZERO,
        igp_oracle: FieldElement::ZERO,
        ism_aggregate: FieldElement::ZERO,
        ism_multisig,
        ism_routing,
        test_mock_hook: FieldElement::ZERO,
        test_mock_ism,
        test_mock_msg_receiver: FieldElement::ZERO,
        warp_strk20: FieldElement::ZERO,
        warp_native: FieldElement::ZERO,
        strk20_base: FieldElement::ZERO,
    })
}

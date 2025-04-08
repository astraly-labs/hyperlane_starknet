use std::future::Future;
use std::sync::Arc;

use starknet::{
    accounts::{Account, ConnectedAccount, SingleOwnerAccount},
    contract::ContractFactory,
    core::types::{
        contract::{CompiledClass, SierraClass},
        BlockId, BlockTag, ExecutionResult, Felt, FlattenedSierraClass,
        InvokeTransactionResult, TransactionReceiptWithBlockInfo, StarknetError,
    },
    macros::felt,
    providers::{jsonrpc::HttpTransport, AnyProvider, JsonRpcClient, Provider, ProviderError, Url},
    signers::{LocalWallet, SigningKey},
};

use super::{types::Codes, StarknetAccount};

const BUILD_PATH_PREFIX: &str = "../cairo/target/dev/contracts_";

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

pub async fn assert_poll<F, Fut>(f: F, polling_time_ms: u64, max_poll_count: u32)
where
    F: Fn() -> Fut,
    Fut: Future<Output = bool>,
{
    for _poll_count in 0..max_poll_count {
        if f().await {
            return; // The provided function returned true, exit safely.
        }

        tokio::time::sleep(tokio::time::Duration::from_millis(polling_time_ms)).await;
    }

    panic!("Max poll count exceeded.");
}

type TransactionReceiptResult = Result<TransactionReceiptWithBlockInfo, ProviderError>;

pub async fn get_transaction_receipt(
    rpc: &AnyProvider,
    transaction_hash: Felt,
) -> TransactionReceiptResult {
    // there is a delay between the transaction being available at the client
    // and the sealing of the block, hence sleeping for 100ms
    assert_poll(
        || async { rpc.get_transaction_receipt(transaction_hash).await.is_ok() },
        100,
        20,
    )
    .await;

    rpc.get_transaction_receipt(transaction_hash).await
}

/// Returns a pre-funded account for a local katana chain.
pub fn get_dev_account(index: u32) -> StarknetAccount {
    let (address, private_key) = *KATANA_PREFUNDED_ACCOUNTS
        .get(index as usize)
        .expect("Invalid index");

    let signer = LocalWallet::from_signing_key(SigningKey::from_secret_scalar(
        Felt::from_hex(&private_key).unwrap(),
    ));

    let mut account = build_single_owner_account(
        &Url::parse(KATANA_RPC_URL).expect("Invalid rpc url"),
        signer,
        &Felt::from_hex(address).unwrap(),
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
    account_address: &Felt,
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
fn contract_artifacts(contract_name: &str) -> eyre::Result<(FlattenedSierraClass, Felt)> {
    let artifact_path = format!("{BUILD_PATH_PREFIX}{contract_name}.contract_class.json");

    let file = std::fs::File::open(artifact_path.clone())?;
    let sierra_class: SierraClass = serde_json::from_reader(file)?;

    let artifact_path = format!("{BUILD_PATH_PREFIX}{contract_name}.compiled_contract_class.json");
    let file = std::fs::File::open(artifact_path)?;

    let compiled_class: CompiledClass = serde_json::from_reader(file)?;

    Ok((sierra_class.flatten()?, compiled_class.class_hash()?))
}

/// Deploys a contract with the given class hash, constructor calldata, and salt.
/// Returns the deployed address and the transaction result.
pub async fn deploy_contract(
    class_hash: Felt,
    constructor_calldata: Vec<Felt>,
    deployer: &StarknetAccount,
) -> (Felt, InvokeTransactionResult) {
    let contract_factory = ContractFactory::new(class_hash, deployer);
    let salt = felt!("0");

    let deployment = contract_factory.deploy(constructor_calldata, salt, false);

    tokio::time::sleep(tokio::time::Duration::from_millis(1000)).await;
    let deploy_res = deployment.send().await.expect("Failed to deploy contract");

    let receipt = get_transaction_receipt(deployer.provider(), deploy_res.transaction_hash)
        .await
        .expect("Failed to get transaction receipt");

    match receipt.receipt.execution_result() {
        ExecutionResult::Reverted { reason } => {
            panic!("Deployment reverted: {}", reason)
        }
        _ => {}
    }

    (deployment.deployed_address(), deploy_res)
}

/// Check if a contract class is already declared.
/// # Arguments
/// * `provider` - The StarkNet provider.
/// * `class_hash` - The contract class hash.
/// # Returns
/// `true` if the contract class is already declared, `false` otherwise.
async fn is_already_declared<P>(provider: &P, class_hash: &Felt) -> eyre::Result<bool>
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
) -> eyre::Result<Felt> {
    // Load the contract artifact.
    let (flattened_class, compiled_class_hash) = contract_artifacts(contract_name)?;
    let class_hash = flattened_class.class_hash();

    // Declare the contract class if it is not already declared.
    if !is_already_declared(account.provider(), &class_hash).await? {
        println!("\n==> Declaring Contract: {contract_name}");
        account
            .declare(Arc::new(flattened_class), compiled_class_hash)
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
    let test_mock_msg_receiver = declare_contract(deployer, "message_recipient").await?;
    let test_mock_hook = declare_contract(deployer, "hook").await?;

    Ok(Codes {
        mailbox,
        va,
        hook_aggregate: Felt::ZERO,
        hook_merkle: Felt::ZERO,
        hook_pausable: Felt::ZERO,
        hook_routing: Felt::ZERO,
        hook_routing_custom: Felt::ZERO,
        hook_routing_fallback: Felt::ZERO,
        igp: Felt::ZERO,
        igp_oracle: Felt::ZERO,
        ism_aggregate: Felt::ZERO,
        ism_multisig,
        ism_routing,
        test_mock_hook,
        test_mock_ism,
        test_mock_msg_receiver,
        warp_strk20: Felt::ZERO,
        warp_native: Felt::ZERO,
        strk20_base: Felt::ZERO,
    })
}

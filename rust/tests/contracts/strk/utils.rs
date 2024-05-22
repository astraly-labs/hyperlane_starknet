use std::future::Future;
use std::sync::Arc;

use starknet::{
    accounts::{Account, ConnectedAccount},
    contract::ContractFactory,
    core::types::{
        contract::{CompiledClass, SierraClass},
        BlockId, BlockTag, ExecutionResult, FieldElement, FlattenedSierraClass,
        InvokeTransactionResult, MaybePendingTransactionReceipt, StarknetError,
    },
    macros::felt,
    providers::{Provider, ProviderError},
};

use super::{
    types::{Codes, StarknetProvider},
    StarknetAccount,
};

const BUILD_PATH_PREFIX: &str = "../contracts/target/dev/hyperlane_starknet_";

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

type TransactionReceiptResult = Result<MaybePendingTransactionReceipt, ProviderError>;

pub async fn get_transaction_receipt(
    rpc: &StarknetProvider,
    transaction_hash: FieldElement,
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

/// Get the contract artifact from the build directory.
/// # Arguments
/// * `path` - The path to the contract artifact.
/// # Returns
/// The contract artifact.
fn contract_artifacts(contract_name: &str) -> eyre::Result<(FlattenedSierraClass, FieldElement)> {
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
    class_hash: FieldElement,
    constructor_calldata: Vec<FieldElement>,
    deployer: &StarknetAccount,
) -> (FieldElement, InvokeTransactionResult) {
    let contract_factory = ContractFactory::new(class_hash, deployer);
    let salt = felt!("0");

    let deployment = contract_factory.deploy(constructor_calldata, salt, false);

    tokio::time::sleep(tokio::time::Duration::from_millis(1000)).await;
    let deploy_res = deployment.send().await.expect("Failed to deploy contract");

    let receipt = get_transaction_receipt(deployer.provider(), deploy_res.transaction_hash)
        .await
        .expect("Failed to get transaction receipt");

    match receipt.execution_result() {
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
        test_mock_msg_receiver,
        warp_strk20: FieldElement::ZERO,
        warp_native: FieldElement::ZERO,
        strk20_base: FieldElement::ZERO,
    })
}

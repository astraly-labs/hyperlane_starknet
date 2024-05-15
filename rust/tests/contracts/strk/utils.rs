use starknet::{
    accounts::SingleOwnerAccount,
    core::types::FieldElement,
    providers::{jsonrpc::HttpTransport, AnyProvider, JsonRpcClient, Url},
    signers::LocalWallet,
};

use super::StarknetAccount;

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

const KATANA_CHAIN_ID: u32 = 82743958523457;

/// Returns a pre-funded account for a local katana chain.
pub fn get_dev_account(index: u32) -> StarknetAccount {
    let (address, private_key) = KATANA_PREFUNDED_ACCOUNTS
        .get(index as usize)
        .expect("Invalid index");

    let signer = LocalWallet::from_signing_key(private_key);
    build_single_owner_account(KATANA_RPC_URL, signer, address, false, KATANA_CHAIN_ID)
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
    chain_id: u32,
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
        chain_id,
        execution_encoding,
    )
}

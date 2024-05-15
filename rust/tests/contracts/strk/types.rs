use std::collections::BTreeMap;

use starknet::{accounts::SingleOwnerAccount, providers::AnyProvider, signers::LocalWallet};

pub type StarknetAccount = SingleOwnerAccount<AnyProvider, LocalWallet>;

#[derive(serde::Serialize, serde::Deserialize)]
pub struct CodesMap(pub BTreeMap<String, u64>);

impl FromIterator<(String, u64)> for CodesMap {
    fn from_iter<T: IntoIterator<Item = (String, u64)>>(iter: T) -> Self {
        Self(iter.into_iter().collect())
    }
}

#[derive(serde::Serialize, serde::Deserialize)]
pub struct Codes {
    pub mailbox: String,
    #[serde(rename = "validator_announce")]
    pub va: String,

    pub hook_aggregate: String,
    pub hook_merkle: String,
    pub hook_pausable: String,
    pub hook_routing: String,
    pub hook_routing_custom: String,
    pub hook_routing_fallback: String,

    pub igp: String,
    pub igp_oracle: String,

    pub ism_aggregate: String,
    pub ism_multisig: String,
    pub ism_routing: String,

    pub test_mock_hook: String,
    pub test_mock_ism: String,
    pub test_mock_msg_receiver: String,

    pub warp_strk20: String,
    pub warp_native: String,

    pub strk20_base: String,
}

impl TryFrom<CodesMap> for Codes {
    type Error = eyre::Error;

    fn try_from(v: CodesMap) -> Result<Self, Self::Error> {
        let bin = serde_json::to_vec(&v)?;

        let ret = serde_json::from_slice(&bin)?;

        Ok(ret)
    }
}

#[derive(serde::Serialize, serde::Deserialize)]
pub struct CoreDeployments {
    pub mailbox: String,
    pub default_ism: String,
    pub default_hook: String,
    pub required_hook: String,
    pub msg_receiver: String,
}

#[derive(serde::Serialize, serde::Deserialize)]
pub struct WarpDeployments(pub BTreeMap<String, String>);

use std::collections::BTreeMap;

use starknet::{
    accounts::SingleOwnerAccount, core::types::Felt, providers::AnyProvider,
    signers::LocalWallet,
};

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
    pub mailbox: Felt,
    #[serde(rename = "validator_announce")]
    pub va: Felt,

    pub hook_aggregate: Felt,
    pub hook_merkle: Felt,
    pub hook_pausable: Felt,
    pub hook_routing: Felt,
    pub hook_routing_custom: Felt,
    pub hook_routing_fallback: Felt,

    pub igp: Felt,
    pub igp_oracle: Felt,

    pub ism_aggregate: Felt,
    pub ism_multisig: Felt,
    pub ism_routing: Felt,

    pub test_mock_hook: Felt,
    pub test_mock_ism: Felt,
    pub test_mock_msg_receiver: Felt,

    pub warp_strk20: Felt,
    pub warp_native: Felt,

    pub strk20_base: Felt,
}

impl TryFrom<CodesMap> for Codes {
    type Error = eyre::Error;

    fn try_from(v: CodesMap) -> Result<Self, Self::Error> {
        let bin = serde_json::to_vec(&v)?;

        let ret = serde_json::from_slice(&bin)?;

        Ok(ret)
    }
}

#[derive(Default, serde::Serialize, serde::Deserialize)]
pub struct CoreDeployments {
    pub mailbox: Felt,
    pub default_ism: Felt,
    pub default_hook: Felt,
    pub required_hook: Felt,
    pub msg_receiver: Felt,
}

#[derive(serde::Serialize, serde::Deserialize)]
pub struct WarpDeployments(pub BTreeMap<String, String>);

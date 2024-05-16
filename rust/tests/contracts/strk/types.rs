use std::collections::BTreeMap;

use starknet::{
    accounts::SingleOwnerAccount, core::types::FieldElement, providers::AnyProvider,
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
    pub mailbox: FieldElement,
    #[serde(rename = "validator_announce")]
    pub va: FieldElement,

    pub hook_aggregate: FieldElement,
    pub hook_merkle: FieldElement,
    pub hook_pausable: FieldElement,
    pub hook_routing: FieldElement,
    pub hook_routing_custom: FieldElement,
    pub hook_routing_fallback: FieldElement,

    pub igp: FieldElement,
    pub igp_oracle: FieldElement,

    pub ism_aggregate: FieldElement,
    pub ism_multisig: FieldElement,
    pub ism_routing: FieldElement,

    pub test_mock_hook: FieldElement,
    pub test_mock_ism: FieldElement,
    pub test_mock_msg_receiver: FieldElement,

    pub warp_strk20: FieldElement,
    pub warp_native: FieldElement,

    pub strk20_base: FieldElement,
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
    pub mailbox: FieldElement,
    pub default_ism: FieldElement,
    pub default_hook: FieldElement,
    pub required_hook: FieldElement,
    pub msg_receiver: FieldElement,
}

#[derive(serde::Serialize, serde::Deserialize)]
pub struct WarpDeployments(pub BTreeMap<String, String>);

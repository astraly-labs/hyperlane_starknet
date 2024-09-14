pub mod setup;
pub mod test_mailbox;
pub mod test_validator_announce;
pub mod isms {
    pub mod test_aggregation;
    pub mod test_default_ism;
    pub mod test_merkleroot_multisig;
    pub mod test_messageid_multisig;
}
pub mod hooks {
    pub mod test_merkle_tree_hook;
    pub mod test_protocol_fee;
}
pub mod routing {
    pub mod test_default_fallback_routing_ism;
    pub mod test_domain_routing_ism;
}
pub mod token {
    pub mod hyp_erc20 {
        pub mod common;
        pub mod hyp_erc20_collateral_test;
        pub mod hyp_erc20_lockbox_test;
        pub mod hyp_erc20_test;
        pub mod hyp_fiat_token_test;
        pub mod hyp_native_test;
        pub mod hyp_xerc20_test;
    }
    pub mod hyp_erc721 {
        pub mod common;
        pub mod hyp_erc721_collateral_test;
        pub mod hyp_erc721_collateral_uri_storage_test;
        pub mod hyp_erc721_test;
        pub mod hyp_erc721_uri_storage_test;
    }

    pub mod vault_extensions {
        pub mod hyp_erc20_collateral_vault_deposit_test;
    }
}
pub mod libs {
    pub mod test_enumerable_map;
}

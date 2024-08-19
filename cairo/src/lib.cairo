mod interfaces;
mod contracts {
    pub mod mailbox;
    pub mod libs {
        pub mod aggregation_ism_metadata;
        pub mod checkpoint_lib;
        pub mod enumerable_map;
        pub mod message;
        pub mod multisig {
            pub mod merkleroot_ism_metadata;
            pub mod message_id_ism_metadata;
        }
    }
    pub mod hooks {
        pub mod merkle_tree_hook;
        pub mod protocol_fee;
        pub mod libs {
            pub mod standard_hook_metadata;
        }
    }
    pub mod client {
        pub mod gas_router_component;
        pub mod mailboxclient;
        pub mod mailboxclient_component;
        pub mod router_component;
    }
    pub mod mocks {
        pub mod fee_hook;
        pub mod fee_token;
        pub mod hook;
        pub mod ism;
        pub mod message_recipient;
        pub mod mock_validator_announce;
        pub mod enumerable_map_holder;
    }
    pub mod token {
        pub mod hyp_erc20;
        pub mod hyp_erc20_collateral;
        pub mod hyp_erc721;
        pub mod hyp_erc721_collateral;
        pub mod hyp_native;
        pub mod extensions {
            pub mod fast_hyp_erc20;
            pub mod fast_hyp_erc20_collateral;
            pub mod hyp_erc20_collateral_vault_deposit;
            pub mod hyp_erc721_URI_collateral;
            pub mod hyp_erc721_URI_storage;
            pub mod hyp_fiat_token;
            pub mod hyp_native_scaled;
            pub mod hyp_xerc20;
            pub mod hyp_xerc20_lockbox;
        }
        pub mod interfaces {
            pub mod ifiat_token;
            pub mod ixerc20;
            pub mod ixerc20_lockbox;
        }
        pub mod components {
            pub mod fast_token_router;
            pub mod hyp_erc721_component;
            pub mod hyp_erc20_component;
            pub mod token_message;
            pub mod token_router;
        }
    }
    pub mod isms {
        pub mod noop_ism;
        pub mod pausable_ism;
        pub mod trusted_relayer_ism;
        pub mod multisig {
            pub mod merkleroot_multisig_ism;
            pub mod messageid_multisig_ism;
            pub mod validator_announce;
        }
        pub mod routing {
            pub mod default_fallback_routing_ism;
            pub mod domain_routing_ism;
        }
        pub mod aggregation {
            pub mod aggregation;
        }
    }
}
mod utils {
    pub mod keccak256;
    pub mod store_arrays;
    pub mod utils;
}

#[cfg(test)]
mod tests {
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
    pub mod libs {
        pub mod test_enumerable_map;
    }
}

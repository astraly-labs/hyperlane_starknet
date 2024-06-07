mod interfaces;
mod contracts {
    pub mod mailbox;
    pub mod libs {
        pub mod aggregation_ism_metadata;
        pub mod checkpoint_lib;
        pub mod merkle_lib;
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
        pub mod mailboxclient;
        pub mod router;
    }
    pub mod mocks {
        pub mod fee_token;
        pub mod hook;
        pub mod ism;
        pub mod message_recipient;
        pub mod mock_validator_announce;
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
}

#[cfg(test)]
mod tests {
    pub mod setup;
    pub mod test_mailbox;
    pub mod isms {
        pub mod test_aggregation;
        pub mod test_multisig;
    }
    pub mod hooks {
        pub mod test_protocol_fee;
    }
}

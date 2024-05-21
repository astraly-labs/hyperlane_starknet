mod interfaces;
mod contracts {
    pub mod mailbox;
    pub mod libs {
        pub mod aggregation_ism_metadata;
        pub mod checkpoint_lib;
        pub mod merkle_lib;
        pub mod message;
        pub mod multisig {
            pub mod message_id_ism_metadata;
        }
    }
    pub mod hooks {
        pub mod merkle_tree_hook;
    }
    pub mod client {
        pub mod mailboxclient;
        pub mod router;
    }
    pub mod mocks {
        pub mod hook;
        pub mod ism;
        pub mod message_recipient;
    }
    pub mod isms {
        pub mod multisig {
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
        // pub mod test_aggregation;
        pub mod test_multisig;
    }
}

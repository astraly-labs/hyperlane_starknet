mod interfaces;
mod contracts {
    pub mod mailbox;
    pub mod libs {
        pub mod checkpoint_lib;
        pub mod message;
        pub mod multisig {
            pub mod message_id_ism_metadata;
        }
    }
    pub mod client {
        pub mod mailboxclient;
        pub mod router;
    }
    pub mod mocks {
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
}

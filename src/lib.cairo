mod interfaces;
mod contracts {
    pub mod mailbox;
    pub mod libs {
        pub mod multisig {
            pub mod message_id_ism_metadata;
        }
        pub mod message;
        pub mod checkpoint_lib;
    }
    pub mod client {
        pub mod mailboxclient;
        pub mod router;
    }
    pub mod mocks {
        pub mod message_recipient;
    }
    pub mod isms {
        pub mod multisig {
            pub mod merkleroot_multisig_ism;
            pub mod messageid_multisig_ism;
            pub mod multisig_ism;
        }
        pub mod routing {
            pub mod domain_routing_ism;
        }
    }
}
mod utils {
    pub mod keccak256;
}

#[cfg(test)]
mod tests {
    pub mod setup;
    pub mod test_mailbox;
    pub mod test_message_id_ism;
}

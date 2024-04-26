mod interfaces;
mod contracts {
    pub mod mailbox;
    pub mod libs {
        pub mod message;
    }
    pub mod client {
        pub mod mailboxclient;
        pub mod router;
    }
}
mod utils {
    pub mod keccak256;
}

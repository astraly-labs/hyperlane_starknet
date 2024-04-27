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
    pub mod mocks {
        pub mod message_recipient;
    }
}
mod utils {
    pub mod keccak256;
}

#[cfg(test)]
mod tests {
    pub mod setup;
    pub mod test_mailbox;
}

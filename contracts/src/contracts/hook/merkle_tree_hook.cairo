#[starknet::contract]
pub mod merkle_tree_hook {
    use hyperlane_starknet::interfaces::{IMailboxClientDispatcher, IMailboxClientDispatcherTrait};
    use starknet::ContractAddress;
    #[storage]
    struct Storage {
        mailbox_client: ContractAddress
    }

    #[constructor]
    fn constructor(ref self: ContractState, _mailbox_client: ContractAddress) {
        self._mailbox_client.write(_mailbox_client);
    }
}
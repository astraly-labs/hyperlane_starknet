#[starknet::contract]
pub mod merkle_tree_hook {
    use alexandria_bytes::{Bytes, BytesTrait};
    use hyperlane_starknet::contracts::libs::merkle_lib::merkle_lib::{Tree, MerkleLib};
    use hyperlane_starknet::contracts::libs::message::{Message, MessageTrait};
    use hyperlane_starknet::interfaces::{
        IMailboxClientDispatcher, IMailboxClientDispatcherTrait, Types, IMerkleTreeHook, IPostDispatchHook
    };
    use hyperlane_starknet::contracts::hooks::libs::standard_hook_metadata::standard_hook_metadata::{
        StandardHookMetadata, VARIANT
    };
    use starknet::ContractAddress;


    #[storage]
    struct Storage {
        mailbox_client: ContractAddress,
        tree: Tree
    }


    pub mod Errors {
        pub const MESSAGE_NOT_DISPATCHING: felt252 = 'Message not dispatching';
        pub const INVALID_METADATA_VARIANT: felt252 = 'Invalid metadata variant';

    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        InsertedIntoTree: InsertedIntoTree
    }

    #[derive(starknet::Event, Drop)]
    pub struct InsertedIntoTree {
        pub id: u256,
        pub index: u32
    }

    #[constructor]
    fn constructor(ref self: ContractState, _mailbox_client: ContractAddress) {
        self.mailbox_client.write(_mailbox_client);
    }

    #[abi(embed_v0)]
    impl IMerkleTreeHookImpl of IMerkleTreeHook<ContractState> {
        fn count(self: @ContractState) -> u32 {
            self.tree.read().count.try_into().unwrap()
        }

        fn root(self: @ContractState) -> u256 {
            self.tree.read().root()
        }

        fn tree(self: @ContractState) -> Tree {
            self.tree.read()
        }

        fn latest_checkpoint(self: @ContractState) -> (u256, u32) {
            (self.root(), self.count())
        }

    }

    #[abi(embed_v0)]
    impl IPostDispatchHookImpl of IPostDispatchHook<ContractState> {
        fn hook_type(self: @ContractState) -> Types {
            Types::MERKLE_TREE(())
        }
        fn supports_metadata(self: @ContractState, _metadata: Bytes) -> bool {
            _metadata.size() == 0 || StandardHookMetadata::variant(_metadata) == VARIANT.into()
        }

        fn post_dispatch(ref self: ContractState, _metadata: Bytes, _message: Message) {
            assert(self.supports_metadata(_metadata.clone()), Errors::INVALID_METADATA_VARIANT);
            self._post_dispatch(_metadata, _message);
        }

        fn quote_dispatch(ref self: ContractState, _metadata: Bytes, _message: Message) -> u256 {
            assert(self.supports_metadata(_metadata.clone()), Errors::INVALID_METADATA_VARIANT);
            self._quote_dispatch(_metadata, _message)
        }
    }
    
    #[generate_trait]
    impl InternalImpl of InternalTrait {
    fn _post_dispatch(ref self: ContractState, _metadata: Bytes, _message: Message) {
        let (id, _) = MessageTrait::format_message(_message);
        let mailbox_client = IMailboxClientDispatcher {
            contract_address: self.mailbox_client.read()
        };
        assert(mailbox_client._is_latest_dispatched(id), Errors::MESSAGE_NOT_DISPATCHING);
        let index = self.count();
        let mut tree = self.tree.read();
        MerkleLib::insert(ref tree, id);
        self.emit(InsertedIntoTree { id, index });
    }

    fn _quote_dispatch(ref self: ContractState, _metadata: Bytes, _message: Message) -> u256 {
        0_u256
    }
    }
}

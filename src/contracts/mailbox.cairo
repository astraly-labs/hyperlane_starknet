#[starknet::contract]
mod mailbox {
    use alexandria_bytes::{Bytes, BytesTrait, BytesStore};
    use core::starknet::SyscallResultTrait;
    use core::starknet::event::EventEmitter;
    use hyperlane_starknet::contracts::libs::message::{Message, MessageTrait};
    use hyperlane_starknet::interfaces::{
        IMailbox, IMailboxDispatcher, IMailboxDispatcherTrait, IInterchainSecurityModuleDispatcher,
        IInterchainSecurityModuleDispatcherTrait, IPostDispatchHookDispatcher,
        ISpecifiesInterchainSecurityModuleDispatcher,
        ISpecifiesInterchainSecurityModuleDispatcherTrait, IPostDispatchHookDispatcherTrait,
        HYPERLANE_VERSION, IMessageRecipientDispatcher, IMessageRecipientDispatcherTrait,
    };
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::upgrades::{interface::IUpgradeable, upgradeable::UpgradeableComponent};
    use starknet::{
        ContractAddress, ClassHash, get_caller_address, get_block_number, contract_address_const
    };


    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[derive(Drop, Serde, starknet::Store)]
    struct Delivery {
        processor: ContractAddress,
        block_number: u64,
    }


    #[storage]
    struct Storage {
        local_domain: u32,
        nonce: u32,
        latest_dispatched_id: u256,
        default_ism: ContractAddress,
        default_hook: ContractAddress,
        required_hook: ContractAddress,
        deliveries: LegacyMap::<u256, Delivery>,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        DefaultIsmSet: DefaultIsmSet,
        DefaultHookSet: DefaultHookSet,
        RequiredHookSet: RequiredHookSet,
        Process: Process,
        ProcessId: ProcessId,
        Dispatch: Dispatch,
        DispatchId: DispatchId,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }

    #[derive(starknet::Event, Drop)]
    struct DefaultIsmSet {
        module: ContractAddress
    }

    #[derive(starknet::Event, Drop)]
    struct DefaultHookSet {
        hook: ContractAddress
    }

    #[derive(starknet::Event, Drop)]
    struct RequiredHookSet {
        hook: ContractAddress
    }

    #[derive(starknet::Event, Drop)]
    struct Process {
        origin: u32,
        sender: ContractAddress,
        recipient: ContractAddress
    }

    #[derive(starknet::Event, Drop)]
    struct ProcessId {
        id: u256
    }

    #[derive(starknet::Event, Drop)]
    struct Dispatch {
        sender: ContractAddress,
        destination_domain: u32,
        recipient_address: ContractAddress,
        message: u256
    }

    #[derive(starknet::Event, Drop)]
    struct DispatchId {
        id: u256
    }


    mod Errors {
        pub const WRONG_HYPERLANE_VERSION: felt252 = 'Wrong hyperlane version';
        pub const UNEXPECTED_DESTINATION: felt252 = 'Unexpected destination';
        pub const ALREADY_DELIVERED: felt252 = 'Mailbox: already delivered';
        pub const ISM_VERIFICATION_FAILED: felt252 = 'Mailbox:ism verification failed';
        pub const NO_ISM_FOUND: felt252 = 'ISM: no ISM found';
    }

    #[constructor]
    fn constructor(ref self: ContractState, _local_domain: u32, owner: ContractAddress) {
        self.local_domain.write(_local_domain);
        self.ownable.initializer(owner);
    }

    #[abi(embed_v0)]
    impl Upgradeable of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable._upgrade(new_class_hash);
        }
    }


    #[abi(embed_v0)]
    impl IMailboxImpl of IMailbox<ContractState> {
        fn initializer(
            ref self: ContractState,
            _default_ism: ContractAddress,
            _default_hook: ContractAddress,
            _required_hook: ContractAddress
        ) {
            self.set_default_ism(_default_ism);
            self.set_default_hook(_default_hook);
            self.set_required_hook(_required_hook);
        }

        fn get_local_domain(self: @ContractState) -> u32 {
            self.local_domain.read()
        }

        fn get_default_ism(self: @ContractState) -> ContractAddress {
            self.default_ism.read()
        }

        fn get_default_hook(self: @ContractState) -> ContractAddress {
            self.default_hook.read()
        }

        fn get_required_hook(self: @ContractState) -> ContractAddress {
            self.required_hook.read()
        }

        fn get_latest_dispatched_id(self: @ContractState) -> u256 {
            self.latest_dispatched_id.read()
        }


        fn set_default_ism(ref self: ContractState, _module: ContractAddress) {
            self.ownable.assert_only_owner();
            self.default_ism.write(_module);
            self.emit(DefaultIsmSet { module: _module });
        }

        fn set_default_hook(ref self: ContractState, _hook: ContractAddress) {
            self.ownable.assert_only_owner();
            self.default_hook.write(_hook);
            self.emit(DefaultHookSet { hook: _hook });
        }

        fn set_required_hook(ref self: ContractState, _hook: ContractAddress) {
            self.ownable.assert_only_owner();
            self.required_hook.write(_hook);
            self.emit(RequiredHookSet { hook: _hook });
        }

        fn set_local_domain(ref self: ContractState, _local_domain: u32) {
            self.ownable.assert_only_owner();
            self.local_domain.write(_local_domain);
        }

        fn dispatch(
            ref self: ContractState,
            _destination_domain: u32,
            _recipient_address: ContractAddress,
            _message_body: Bytes,
            _custom_hook_metadata: Option<Bytes>,
            _custom_hook: Option<ContractAddress>
        ) -> u256 {
            let hook = match _custom_hook {
                Option::Some(hook) => hook,
                Option::None(()) => self.default_hook.read(),
            };
            let hook_metadata = match _custom_hook_metadata {
                Option::Some(hook_metadata) => hook_metadata,
                Option::None(()) => BytesTrait::new_empty()
            };

            let message = build_message(
                @self, _destination_domain, _recipient_address, _message_body
            );
            let id = message;
            self.latest_dispatched_id.write(id);
            let current_nonce = self.nonce.read();
            self.nonce.write(current_nonce + 1);
            let caller = get_caller_address();
            self
                .emit(
                    Dispatch {
                        sender: caller,
                        destination_domain: _destination_domain,
                        recipient_address: _recipient_address,
                        message: message
                    }
                );
            self.emit(DispatchId { id: id });
            let required_hook_address = self.required_hook.read();
            let required_hook = IPostDispatchHookDispatcher {
                contract_address: required_hook_address
            };
            let hook = IPostDispatchHookDispatcher { contract_address: hook };
            let mut required_value = required_hook.quote_dispatch(hook_metadata.clone(), message);
            let max_fee = starknet::get_tx_info().unbox().max_fee.into();
            if (max_fee < required_value) {
                required_value = max_fee;
            }
            required_hook.post_dispatch(hook_metadata.clone(), message);
            hook.post_dispatch(hook_metadata, message);
            id
        }

        fn delivered(self: @ContractState, _message_id: u256) -> bool {
            self.deliveries.read(_message_id).block_number > 0
        }

        fn process(ref self: ContractState, _metadata: Bytes, _message: Message) {
            assert(_message.version == HYPERLANE_VERSION, Errors::WRONG_HYPERLANE_VERSION);
            assert(
                _message.destination == self.local_domain.read(), Errors::UNEXPECTED_DESTINATION
            );
            let id = MessageTrait::format_message(_message.clone());
            let caller = get_caller_address();
            let block_number = get_block_number();
            assert(!self.delivered(id), Errors::ALREADY_DELIVERED);
            let recipient_ism = self.recipient_ism(_message.recipient);
            let ism = IInterchainSecurityModuleDispatcher { contract_address: recipient_ism };
            self.deliveries.write(id, Delivery { processor: caller, block_number: block_number });
            self
                .emit(
                    Process {
                        origin: _message.origin,
                        sender: _message.sender,
                        recipient: _message.recipient
                    }
                );
            self.emit(ProcessId { id: id });
            assert(ism.verify(_metadata, _message.clone()), Errors::ISM_VERIFICATION_FAILED);
            let message_recipient = IMessageRecipientDispatcher {
                contract_address: _message.recipient
            };
            message_recipient.handle(_message.origin, _message.sender, _message.body);
        }
        fn quote_dispatch(
            ref self: ContractState,
            _destination_domain: u32,
            _recipient_address: ContractAddress,
            _message_body: Bytes,
            _custom_hook_metadata: Option<Bytes>,
            _custom_hook: Option<ContractAddress>,
        ) -> u256 {
            let hook_address = match _custom_hook {
                Option::Some(hook) => hook,
                Option::None(()) => self.default_hook.read()
            };
            let hook_metadata = match _custom_hook_metadata {
                Option::Some(hook_metadata) => hook_metadata,
                Option::None(()) => BytesTrait::new_empty(),
            };
            let message = build_message(
                @self, _destination_domain, _recipient_address, _message_body.clone()
            );
            let required_hook_address = self.required_hook.read();
            let required_hook = IPostDispatchHookDispatcher {
                contract_address: required_hook_address
            };
            let hook = IPostDispatchHookDispatcher { contract_address: hook_address };
            required_hook.quote_dispatch(hook_metadata.clone(), message.clone())
                - hook.quote_dispatch(hook_metadata, message)
        }

        fn recipient_ism(ref self: ContractState, _recipient: ContractAddress) -> ContractAddress {
            let mut call_data: Array<felt252> = ArrayTrait::new();
            let mut res = starknet::syscalls::call_contract_syscall(
                _recipient, selector!("interchain_security_module"), call_data.span()
            );
            let mut ism_res = match res {
                Result::Ok(ism) => ism,
                Result::Err(revert_reason) => {
                    assert(revert_reason == array!['ENTRYPOINT_FAILED'], Errors::NO_ISM_FOUND);
                    array![].span()
                }
            };
            if (ism_res.len() != 0) {
                let ism_address = Serde::<ContractAddress>::deserialize(ref ism_res).unwrap();
                if (ism_address != contract_address_const::<0>()) {
                    return ism_address;
                }
            }
            self.default_ism.read()
        }

        fn processor(self: @ContractState, _id: u256) -> ContractAddress {
            self.deliveries.read(_id).processor
        }

        fn processed_at(self: @ContractState, _id: u256) -> u64 {
            self.deliveries.read(_id).block_number
        }
    }

    fn build_message(
        self: @ContractState,
        _destination_domain: u32,
        _recipient_address: ContractAddress,
        _message_body: Bytes
    ) -> u256 {
        let nonce = self.nonce.read();
        let local_domain = self.local_domain.read();
        let caller = get_caller_address();
        MessageTrait::format_message(
            Message {
                version: HYPERLANE_VERSION,
                nonce: nonce,
                origin: local_domain,
                sender: caller,
                destination: _destination_domain,
                recipient: _recipient_address,
                body: _message_body
            }
        )
    }
}


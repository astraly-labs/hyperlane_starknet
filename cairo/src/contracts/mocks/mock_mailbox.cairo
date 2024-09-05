use alexandria_bytes::Bytes;
use hyperlane_starknet::contracts::libs::message::Message;
use hyperlane_starknet::interfaces::IPostDispatchHookDispatcher;
use starknet::ContractAddress;

#[starknet::interface]
pub trait IMockMailbox<TContractState> {
    fn add_remote_mail_box(ref self: TContractState, _domain: u32, _mailbox: ContractAddress);
    fn dispatch(
        ref self: TContractState,
        destination_domain: u32,
        recipient: u256,
        message_body: Bytes,
        metadata: Bytes,
        hook: ContractAddress,
    ) -> u256;
    fn add_inbound_message(ref self: TContractState, message: Message);
    fn process_next_inbound_message(ref self: TContractState);
}

#[starknet::contract]
pub mod MockMailbox {
    use alexandria_bytes::{Bytes, BytesTrait};
    use hyperlane_starknet::contracts::libs::message::{Message, MessageTrait};
    use hyperlane_starknet::contracts::mailbox::mailbox::{Errors, Delivery,};
    use hyperlane_starknet::contracts::mocks::test_post_dispatch_hook::IPostDispatchHookMockDispatcher;
    use hyperlane_starknet::interfaces::{
        IMailboxDispatcher, IMailboxDispatcherTrait, IInterchainSecurityModuleDispatcher,
        IInterchainSecurityModuleDispatcherTrait, IPostDispatchHookDispatcher,
        IPostDispatchHookDispatcherTrait, ETH_ADDRESS, IMessageRecipientDispatcher,
        IMessageRecipientDispatcherTrait
    };
    use hyperlane_starknet::utils::utils::U256TryIntoContractAddress;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use starknet::ContractAddress;
    use super::{IMockMailboxDispatcher, IMockMailboxDispatcherTrait};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        deliveries: LegacyMap::<u256, Delivery>,
        required_hook: ContractAddress,
        latest_dispatched_id: u256,
        local_domain: u32,
        nonce: u32,
        default_ism: ContractAddress,
        default_hook: ContractAddress,
        inbound_unprocessed_nonce: u32,
        inbound_processed_nonce: u32,
        remote_mailboxes: LegacyMap<u32, ContractAddress>,
        inbound_messages: LegacyMap<u32, Message>,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        Dispatch: Dispatch,
        DispatchId: DispatchId,
        Process: Process,
        ProcessId: ProcessId,
    }

    #[derive(starknet::Event, Drop)]
    pub struct Dispatch {
        pub sender: u256,
        pub destination_domain: u32,
        pub recipient_address: u256,
        pub message: Message
    }

    #[derive(starknet::Event, Drop)]
    pub struct DispatchId {
        pub id: u256
    }

    #[derive(starknet::Event, Drop)]
    pub struct Process {
        pub origin: u32,
        pub sender: u256,
        pub recipient: u256
    }

    #[derive(starknet::Event, Drop)]
    pub struct ProcessId {
        pub id: u256
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        domain: u32,
        default_ism: ContractAddress,
        default_hook: ContractAddress
    ) {
        self.local_domain.write(domain);
        self.default_ism.write(default_ism);
        self.default_hook.write(default_hook);

        self.ownable.initializer(starknet::get_caller_address());
    }

    #[abi(embed_v0)]
    impl IMockMailboxImpl of super::IMockMailbox<ContractState> {
        fn add_remote_mail_box(ref self: ContractState, _domain: u32, _mailbox: ContractAddress) {
            self.remote_mailboxes.write(_domain, _mailbox);
        }

        fn dispatch(
            ref self: ContractState,
            destination_domain: u32,
            recipient: u256,
            message_body: Bytes,
            metadata: Bytes,
            hook: ContractAddress
        ) -> u256 {
            let (_, message) = self
                .build_message(destination_domain, recipient, message_body.clone());
            let id = self
                ._dispatch(
                    destination_domain,
                    recipient,
                    message_body,
                    0,
                    Option::Some(metadata),
                    Option::Some(hook)
                );
            let destination_mailbox = self.remote_mailboxes.read(destination_domain);
            assert!(
                destination_mailbox != starknet::contract_address_const::<0>(),
                "Missing remote mailbox"
            );

            IMockMailboxDispatcher { contract_address: destination_mailbox }
                .add_inbound_message(message);

            id
        }

        fn add_inbound_message(ref self: ContractState, message: Message) {
            self.inbound_messages.write(self.inbound_unprocessed_nonce.read(), message);
            self.inbound_unprocessed_nonce.write(self.inbound_unprocessed_nonce.read() + 1);
        }

        fn process_next_inbound_message(ref self: ContractState) {
            let message = self.inbound_messages.read(self.inbound_unprocessed_nonce.read());
            IMailboxDispatcher { contract_address: starknet::get_contract_address() }
                .process(BytesTrait::new_empty(), message);
            self.inbound_processed_nonce.write(self.inbound_processed_nonce.read() + 1);
        }
    }

    #[generate_trait]
    impl Private of PrivateTrait {
        fn build_message(
            self: @ContractState,
            _destination_domain: u32,
            _recipient_address: u256,
            _message_body: Bytes
        ) -> (u256, Message) {
            let nonce = self.nonce.read();
            let local_domain = self.local_domain.read();
            let caller: felt252 = starknet::get_caller_address().into();
            MessageTrait::format_message(
                Message {
                    version: 3,
                    nonce: nonce,
                    origin: local_domain,
                    sender: caller.into(),
                    destination: _destination_domain,
                    recipient: _recipient_address,
                    body: _message_body
                }
            )
        }

        fn delivered(self: @ContractState, _message_id: u256) -> bool {
            self.deliveries.read(_message_id).block_number > 0
        }

        fn recipient_ism(self: @ContractState, _recipient: u256) -> ContractAddress {
            let mut call_data: Array<felt252> = ArrayTrait::new();
            let mut res = starknet::syscalls::call_contract_syscall(
                _recipient.try_into().unwrap(),
                selector!("interchain_security_module"),
                call_data.span()
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
                if (ism_address != starknet::contract_address_const::<0>()) {
                    return ism_address;
                }
            }
            self.default_ism.read()
        }

        fn process(ref self: ContractState, _metadata: Bytes, _message: Message) {
            let mut sanitized_bytes_metadata = BytesTrait::new_empty();
            sanitized_bytes_metadata.concat(@_metadata);
            assert(sanitized_bytes_metadata == _metadata, Errors::SIZE_DOES_NOT_MATCH_METADATA);
            let mut sanitized_bytes_message_body = BytesTrait::new_empty();
            sanitized_bytes_message_body.concat(@_message.body);
            assert(
                sanitized_bytes_message_body == _message.body,
                Errors::SIZE_DOES_NOT_MATCH_MESSAGE_BODY
            );

            assert(_message.version == 3, Errors::WRONG_HYPERLANE_VERSION);
            assert(
                _message.destination == self.local_domain.read(), Errors::UNEXPECTED_DESTINATION
            );
            let (id, _) = MessageTrait::format_message(_message.clone());
            let caller = starknet::get_caller_address();
            let block_number = starknet::get_block_number();
            assert(!self.delivered(id), Errors::ALREADY_DELIVERED);

            self.deliveries.write(id, Delivery { processor: caller, block_number: block_number });

            let recipient_ism = self.recipient_ism(_message.recipient);
            let ism = IInterchainSecurityModuleDispatcher { contract_address: recipient_ism };

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
                contract_address: _message.recipient.try_into().unwrap()
            };
            message_recipient.handle(_message.origin, _message.sender, _message.body);
        }

        fn _dispatch(
            ref self: ContractState,
            _destination_domain: u32,
            _recipient_address: u256,
            _message_body: Bytes,
            _fee_amount: u256,
            _custom_hook_metadata: Option<Bytes>,
            _custom_hook: Option<ContractAddress>
        ) -> u256 {
            let hook = match _custom_hook {
                Option::Some(hook) => hook,
                Option::None(()) => self.default_hook.read(),
            };
            let hook_metadata = match _custom_hook_metadata {
                Option::Some(hook_metadata) => {
                    let mut sanitized_bytes_metadata = BytesTrait::new_empty();
                    sanitized_bytes_metadata.concat(@hook_metadata);
                    assert(
                        sanitized_bytes_metadata == hook_metadata,
                        Errors::SIZE_DOES_NOT_MATCH_METADATA
                    );
                    hook_metadata
                },
                Option::None(()) => BytesTrait::new_empty()
            };
            let mut sanitized_bytes_message_body = BytesTrait::new_empty();
            sanitized_bytes_message_body.concat(@_message_body);
            assert(
                sanitized_bytes_message_body == _message_body,
                Errors::SIZE_DOES_NOT_MATCH_MESSAGE_BODY
            );
            let (id, message) = self
                .build_message(_destination_domain, _recipient_address, _message_body);
            self.latest_dispatched_id.write(id);
            let current_nonce = self.nonce.read();
            self.nonce.write(current_nonce + 1);
            let caller: felt252 = starknet::get_caller_address().into();
            self
                .emit(
                    Dispatch {
                        sender: caller.into(),
                        destination_domain: _destination_domain,
                        recipient_address: _recipient_address,
                        message: message.clone()
                    }
                );
            self.emit(DispatchId { id: id });

            // HOOKS

            let required_hook_address = self.required_hook.read();
            let required_hook = IPostDispatchHookDispatcher {
                contract_address: required_hook_address
            };
            let mut required_fee = required_hook
                .quote_dispatch(hook_metadata.clone(), message.clone());

            let hook_dispatcher = IPostDispatchHookDispatcher { contract_address: hook };
            let default_fee = hook_dispatcher
                .quote_dispatch(hook_metadata.clone(), message.clone());

            assert(_fee_amount >= required_fee + default_fee, Errors::NOT_ENOUGH_FEE_PROVIDED);

            let caller_address = starknet::get_caller_address();
            let contract_address = starknet::get_contract_address();

            let token_dispatcher = ERC20ABIDispatcher { contract_address: ETH_ADDRESS() };
            let user_balance = token_dispatcher.balanceOf(caller_address);

            assert(user_balance >= required_fee + default_fee, Errors::INSUFFICIENT_BALANCE);

            assert(
                token_dispatcher.allowance(caller_address, contract_address) >= _fee_amount,
                Errors::INSUFFICIENT_ALLOWANCE
            );

            if (required_fee > 0) {
                token_dispatcher.transferFrom(caller_address, required_hook_address, required_fee);
            }
            required_hook.post_dispatch(hook_metadata.clone(), message.clone(), required_fee);

            if (default_fee > 0) {
                token_dispatcher.transferFrom(caller_address, hook, default_fee);
            }
            hook_dispatcher.post_dispatch(hook_metadata, message.clone(), default_fee);

            id
        }
    }
}

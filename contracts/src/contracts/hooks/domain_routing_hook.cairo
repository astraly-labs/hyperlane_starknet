#[starknet::contract]
pub mod domain_routing_hook {
    use alexandria_bytes::{Bytes, BytesTrait, BytesStore};
    use hyperlane_starknet::contracts::client::mailboxclient_component::{
        MailboxclientComponent, MailboxclientComponent::MailboxClientInternalImpl
    };
    use hyperlane_starknet::contracts::client::{mailboxclient};
    use hyperlane_starknet::contracts::libs::message::Message;
    use hyperlane_starknet::interfaces::{
        IPostDispatchHook, IPostDispatchHookDispatcher, IPostDispatchHookDispatcherTrait,
        DomainRoutingHookConfig, IDomainRoutingHook, Types, IPostDispatchHookForDomainRoutingHook,
    };
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::interface::{IERC20, IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::upgrades::{interface::IUpgradeable, upgradeable::UpgradeableComponent};
    use starknet::{
        ContractAddress, contract_address_const, get_caller_address, get_contract_address
    };
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: MailboxclientComponent, storage: mailboxclient, event: MailboxclientEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;


    #[storage]
    struct Storage {
        hooks: LegacyMap<u32, IPostDispatchHookDispatcher>,
        fee_token: ContractAddress,
        #[substorage(v0)]
        mailboxclient: MailboxclientComponent::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
    }


    mod Errors {
        pub const INVALID_DESTINATION: felt252 = 'Destination has no hooks';
        pub const INSUFFICIENT_BALANCE: felt252 = 'Insufficient balance';
        pub const FEE_AMOUNT_TRANSFER_FAILED: felt252 = 'Hook fee transfer failed';
        pub const ZERO_FEE: felt252 = 'Zero fee amount';
        pub const INSUFFICIENT_ALLOWANCE: felt252 = 'Insufficient allowance';
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        MailboxclientEvent: MailboxclientComponent::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        _mailbox: ContractAddress,
        _owner: ContractAddress,
        _fee_token_address: ContractAddress
    ) {
        self.mailboxclient.initialize(_mailbox);
        self.ownable.initializer(_owner);
        self.fee_token.write(_fee_token_address);
    }

    #[abi(embed_v0)]
    impl IPostDispatchHookForDomainRoutingHookImpl of IPostDispatchHookForDomainRoutingHook<
        ContractState
    > {
        fn hook_type(self: @ContractState) -> Types {
            Types::ROUTING(())
        }

        fn supports_metadata(self: @ContractState, _metadata: Bytes) -> bool {
            true
        }

        fn post_dispatch(
            ref self: ContractState, _metadata: Bytes, _message: Message, _fee_amount: u256
        ) {
            assert(_fee_amount > 0, Errors::ZERO_FEE);
            let caller = get_caller_address();
            let configured_hook_address: ContractAddress = self
                ._get_configured_hook(_message.clone())
                .contract_address;
            self._transfer_routing_fee_to_hook(caller, configured_hook_address, _fee_amount);
            self._get_configured_hook(_message.clone()).post_dispatch(_metadata, _message);
        }

        fn quote_dispatch(ref self: ContractState, _metadata: Bytes, _message: Message) -> u256 {
            self._get_configured_hook(_message.clone()).quote_dispatch(_metadata, _message)
        }
    }

    #[abi(embed_v0)]
    impl IDomainRoutingHookImpl of IDomainRoutingHook<ContractState> {
        fn set_hook(ref self: ContractState, _destination: u32, _hook: ContractAddress) {
            self.ownable.assert_only_owner();
            self.hooks.write(_destination, IPostDispatchHookDispatcher { contract_address: _hook });
        }
        fn set_hooks(ref self: ContractState, configs: Array<DomainRoutingHookConfig>) {
            self.ownable.assert_only_owner();
            let mut configs_span = configs.span();
            loop {
                match configs_span.pop_front() {
                    Option::Some(config) => { self.set_hook(*config.destination, *config.hook) },
                    Option::None(_) => { break; },
                };
            };
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _get_configured_hook(
            self: @ContractState, _message: Message
        ) -> IPostDispatchHookDispatcher {
            let dispatcher_instance = self.hooks.read(_message.destination);
            assert(
                dispatcher_instance.contract_address != contract_address_const::<0>(),
                Errors::INVALID_DESTINATION
            );
            dispatcher_instance
        }

        fn _transfer_routing_fee_to_hook(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, amount: u256
        ) {
            let token_dispatcher = IERC20Dispatcher { contract_address: self.fee_token.read() };
            let user_balance = token_dispatcher.balance_of(from);
            assert(user_balance >= amount, Errors::INSUFFICIENT_BALANCE);
            let contract_address = get_contract_address();
            assert(
                token_dispatcher.allowance(from, contract_address) >= amount,
                Errors::INSUFFICIENT_ALLOWANCE
            );
            let transfer_flag: bool = token_dispatcher.transfer_from(from, to, amount);
            assert(transfer_flag == false, Errors::FEE_AMOUNT_TRANSFER_FAILED);
        }
    }
}

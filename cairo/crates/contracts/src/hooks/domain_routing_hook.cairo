#[starknet::contract]
pub mod domain_routing_hook {
    use alexandria_bytes::{Bytes, BytesTrait, BytesStore};
    use contracts::client::mailboxclient_component::{
        MailboxclientComponent, MailboxclientComponent::MailboxClientInternalImpl
    };
    use contracts::client::{mailboxclient};
    use contracts::interfaces::{
        IPostDispatchHook, IPostDispatchHookDispatcher, IPostDispatchHookDispatcherTrait,
        DomainRoutingHookConfig, IDomainRoutingHook, Types
    };
    use contracts::libs::message::Message;
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
        domains: LegacyMap<u32, u32>,
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
        pub const ZERO_FEE: felt252 = 'Zero fee amount';
        pub const INSUFFICIENT_ALLOWANCE: felt252 = 'Insufficient allowance';
        pub const AMOUNT_DOES_NOT_COVER_HOOK_QUOTE: felt252 = 'Amount does not cover quote fee';
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
        self.mailboxclient.initialize(_mailbox, Option::None, Option::None);
        self.ownable.initializer(_owner);
        self.fee_token.write(_fee_token_address);
    }

    #[abi(embed_v0)]
    impl IPostDispatchHookImpl of IPostDispatchHook<ContractState> {
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

            // We should check that the fee_amount is enough for the desired hook to work before actually send the amount
            // We assume that the fee token is the same across the hooks

            let required_amount = self.quote_dispatch(_metadata.clone(), _message.clone());
            assert(_fee_amount >= required_amount, Errors::AMOUNT_DOES_NOT_COVER_HOOK_QUOTE);

            let caller = get_caller_address();
            let configured_hook_address: ContractAddress = self
                ._get_configured_hook(_message.clone())
                .contract_address;

            // Tricky here: if the destination hook does operations with the transfered fee, we need to send it before
            // the operation. However, if we send the fee before and for an unexpected reason the destination hook reverts,
            // it will have to send back the token to the caller. For now, we assume that the destination hook does not 
            // do anything with the fee, so we can send it after the `_post_dispatch` call. 
            self
                ._get_configured_hook(_message.clone())
                .post_dispatch(_metadata, _message, _fee_amount);
            self._transfer_routing_fee_to_hook(caller, configured_hook_address, required_amount);
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
        fn get_hook(self: @ContractState, domain: u32) -> ContractAddress {
            self.hooks.read(domain).contract_address
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
            let this_contract_address = get_contract_address();
            assert(
                token_dispatcher.allowance(from, this_contract_address) >= amount,
                Errors::INSUFFICIENT_ALLOWANCE
            );
            token_dispatcher.transfer_from(from, to, amount);
        }
    }
}

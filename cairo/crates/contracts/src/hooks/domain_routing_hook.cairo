/// WARNING: THIS CONTRACT IS NOT AUDITED

#[starknet::contract]
pub mod domain_routing_hook {
    use alexandria_bytes::{Bytes, BytesStore};
    use contracts::client::mailboxclient_component::{
        MailboxclientComponent, MailboxclientComponent::MailboxClientInternalImpl,
    };
    use contracts::interfaces::{
        DomainRoutingHookConfig, IDomainRoutingHook, IPostDispatchHook, IPostDispatchHookDispatcher,
        IPostDispatchHookDispatcherTrait, Types,
    };
    use contracts::libs::message::Message;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::upgrades::upgradeable::UpgradeableComponent;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{
        ContractAddress, contract_address_const, get_caller_address, get_contract_address,
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
        /// Mapping of domain IDs to their corresponding post-dispatch hooks
        hooks: Map<u32, IPostDispatchHookDispatcher>,
        /// The ERC20 token address used for paying routing fees
        fee_token: ContractAddress,
        #[substorage(v0)]
        mailboxclient: MailboxclientComponent::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
    }


    mod Errors {
        /// Error when no hooks are configured for a destination domain
        pub const INVALID_DESTINATION: felt252 = 'Destination has no hooks';
        /// Error when user has insufficient token balance
        pub const INSUFFICIENT_BALANCE: felt252 = 'Insufficient balance';
        /// Error when fee amount is zero
        pub const ZERO_FEE: felt252 = 'Zero fee amount';
        /// Error when user has insufficient token allowance
        pub const INSUFFICIENT_ALLOWANCE: felt252 = 'Insufficient allowance';
        /// Error when provided fee does not cover the hook quote
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


    /// Constructor of the contract
    ///
    /// # Arguments
    ///
    /// * `_mailbox` - The address of the mailbox contract
    /// * `_owner` - The owner of the contract
    /// * `_fee_token_address` - The address of the ERC20 token used for routing fees
    #[constructor]
    fn constructor(
        ref self: ContractState,
        _mailbox: ContractAddress,
        _owner: ContractAddress,
        _fee_token_address: ContractAddress,
    ) {
        self.mailboxclient.initialize(_mailbox, Option::None, Option::None);
        self.ownable.initializer(_owner);
        self.fee_token.write(_fee_token_address);
    }

    #[abi(embed_v0)]
    impl IPostDispatchHookImpl of IPostDispatchHook<ContractState> {
        /// Returns the type of hook (routing)
        fn hook_type(self: @ContractState) -> Types {
            Types::ROUTING(())
        }

        /// Always returns true to support all metadata
        ///
        /// # Arguments
        ///
        /// * `_metadata` - Metadata for the hook
        ///
        /// # Returns
        ///
        /// boolean - whether the hook supports the metadata
        fn supports_metadata(self: @ContractState, _metadata: Bytes) -> bool {
            true
        }

        /// Post-dispatch action for routing hooks
        /// dev: the provided fee amount must not be zero,
        /// cover the quote dispatch of the associated hook.
        ///
        /// # Arguments
        ///
        /// * `_metadata` - Metadata for the hook
        /// * `_message` - The message being dispatched
        /// * `_fee_amount` - The fee amount provided for routing
        ///
        /// # Errors
        ///
        /// Reverts with `AMOUNT_DOES_NOT_COVER_HOOK_QUOTE` if the fee amount does not cover the
        /// hook quote
        fn post_dispatch(
            ref self: ContractState, _metadata: Bytes, _message: Message, _fee_amount: u256,
        ) {
            // We should check that the fee_amount is enough for the desired hook to work before
            // actually send the amount We assume that the fee token is the same across the hooks

            let required_amount = self.quote_dispatch(_metadata.clone(), _message.clone());
            assert(_fee_amount >= required_amount, Errors::AMOUNT_DOES_NOT_COVER_HOOK_QUOTE);

            let caller = get_caller_address();
            let configured_hook_address: ContractAddress = self
                ._get_configured_hook(_message.clone())
                .contract_address;

            if (required_amount > 0) {
                self
                    ._transfer_routing_fee_to_hook(
                        caller, configured_hook_address, required_amount,
                    );
            };
            self
                ._get_configured_hook(_message.clone())
                .post_dispatch(_metadata, _message, required_amount);
        }

        /// Quotes the dispatch fee for a given message. The hook to be selected will be based on
        /// the destination of the message input
        ///
        /// # Arguments
        ///
        /// * `_metadata` - Metadata for the hook
        /// * `_message` - The message being dispatched
        ///
        /// # Returns
        ///
        /// u256 - The quoted fee for dispatching the message
        fn quote_dispatch(ref self: ContractState, _metadata: Bytes, _message: Message) -> u256 {
            self._get_configured_hook(_message.clone()).quote_dispatch(_metadata, _message)
        }
    }

    #[abi(embed_v0)]
    impl IDomainRoutingHookImpl of IDomainRoutingHook<ContractState> {
        /// Sets a hook for a specific destination domain
        ///
        /// # Arguments
        ///
        /// * `_destination` - The destination domain ID
        /// * `_hook` - The address of the hook contract for this domain
        fn set_hook(ref self: ContractState, _destination: u32, _hook: ContractAddress) {
            self.ownable.assert_only_owner();
            self.hooks.write(_destination, IPostDispatchHookDispatcher { contract_address: _hook });
        }

        /// Sets multiple hooks for different destination domains in a single call
        ///
        /// # Arguments
        ///
        /// * `configs` - An array of domain routing hook configurations
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

        /// Retrieves the hook address for a specific domain
        ///
        /// # Arguments
        ///
        /// * `domain` - The domain ID
        ///
        /// # Returns
        ///
        /// ContractAddress - The address of the hook for the specified domain
        fn get_hook(self: @ContractState, domain: u32) -> ContractAddress {
            self.hooks.read(domain).contract_address
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// Retrieves the configured hook for a given message's destination
        ///
        /// # Arguments
        ///
        /// * `_message` - The message to route
        ///
        /// # Returns
        ///
        /// IPostDispatchHookDispatcher - The dispatcher for the configured hook
        ///
        /// # Errors
        ///
        /// Reverts with `INVALID_DESTINATION` if no hook is configured for the destination
        fn _get_configured_hook(
            self: @ContractState, _message: Message,
        ) -> IPostDispatchHookDispatcher {
            let dispatcher_instance = self.hooks.read(_message.destination);
            assert(
                dispatcher_instance.contract_address != contract_address_const::<0>(),
                Errors::INVALID_DESTINATION,
            );
            dispatcher_instance
        }

        /// Transfers routing fees from the caller to the destination hook
        ///
        /// # Arguments
        ///
        /// * `from` - The address sending the fees
        /// * `to` - The address receiving the fees
        /// * `amount` - The amount of fees to transfer
        ///
        /// # Errors
        ///
        /// Reverts with `INSUFFICIENT_BALANCE` or `INSUFFICIENT_ALLOWANCE` respectively if the user
        /// balance/allowance does not mathc requirements
        fn _transfer_routing_fee_to_hook(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, amount: u256,
        ) {
            let token_dispatcher = IERC20Dispatcher { contract_address: self.fee_token.read() };
            let user_balance = token_dispatcher.balance_of(from);
            assert(user_balance >= amount, Errors::INSUFFICIENT_BALANCE);
            let this_contract_address = get_contract_address();
            assert(
                token_dispatcher.allowance(from, this_contract_address) >= amount,
                Errors::INSUFFICIENT_ALLOWANCE,
            );
            token_dispatcher.transfer_from(from, to, amount);
        }
    }
}

#[starknet::interface]
pub trait IHypXERC20Lockbox<TState> {
    fn approve_lockbox(ref self: TState);
}

#[starknet::contract]
pub mod HypXERC20Lockbox {
    use alexandria_bytes::{Bytes, BytesTrait};
    use core::integer::BoundedInt;
    use hyperlane_starknet::contracts::client::gas_router_component::GasRouterComponent;
    use hyperlane_starknet::contracts::client::mailboxclient_component::MailboxclientComponent;
    use hyperlane_starknet::contracts::client::router_component::RouterComponent;
    use hyperlane_starknet::contracts::token::components::{
        hyp_erc20_collateral_component::HypErc20CollateralComponent,
        token_message::TokenMessageTrait, token_router::{TokenRouterComponent, ITokenRouter},
    };
    use hyperlane_starknet::contracts::token::interfaces::imessage_recipient::IMessageRecipient;
    use hyperlane_starknet::contracts::token::interfaces::ixerc20::{
        IXERC20Dispatcher, IXERC20DispatcherTrait
    };
    use hyperlane_starknet::contracts::token::interfaces::ixerc20_lockbox::{
        IXERC20LockboxDispatcher, IXERC20LockboxDispatcherTrait
    };
    use hyperlane_starknet::utils::utils::U256TryIntoContractAddress;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::interface::{IERC20, IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::ContractAddress;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: MailboxclientComponent, storage: mailbox, event: MailBoxClientEvent);
    component!(path: RouterComponent, storage: router, event: RouterEvent);
    component!(path: GasRouterComponent, storage: gas_router, event: GasRouterEvent);
    component!(path: TokenRouterComponent, storage: token_router, event: TokenRouterEvent);
    component!(
        path: HypErc20CollateralComponent, storage: collateral, event: HypErc20CollateralEvent
    );

    // Ownable
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    // MailboxClient
    #[abi(embed_v0)]
    impl MailboxClientImpl =
        MailboxclientComponent::MailboxClientImpl<ContractState>;
    impl MailboxClientInternalImpl =
        MailboxclientComponent::MailboxClientInternalImpl<ContractState>;
    // Router
    #[abi(embed_v0)]
    impl RouterImpl = RouterComponent::RouterImpl<ContractState>;
    impl RouterInternalImpl = RouterComponent::RouterComponentInternalImpl<ContractState>;
    // GasRouter
    #[abi(embed_v0)]
    impl GasRouterImpl = GasRouterComponent::GasRouterImpl<ContractState>;
    impl GasRouterInternalImpl = GasRouterComponent::GasRouterInternalImpl<ContractState>;
    // HypERC20Collateral
    #[abi(embed_v0)]
    impl HypErc20CollateralImpl =
        HypErc20CollateralComponent::HypErc20CollateralImpl<ContractState>;
    impl HypErc20CollateralInternalImpl = HypErc20CollateralComponent::InternalImpl<ContractState>;
    #[storage]
    struct Storage {
        #[substorage(v0)]
        collateral: HypErc20CollateralComponent::Storage,
        #[substorage(v0)]
        mailbox: MailboxclientComponent::Storage,
        #[substorage(v0)]
        token_router: TokenRouterComponent::Storage,
        #[substorage(v0)]
        gas_router: GasRouterComponent::Storage,
        #[substorage(v0)]
        router: RouterComponent::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        lockbox: IXERC20LockboxDispatcher,
        xerc20: IXERC20Dispatcher,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        HypErc20CollateralEvent: HypErc20CollateralComponent::Event,
        #[flat]
        MailBoxClientEvent: MailboxclientComponent::Event,
        #[flat]
        GasRouterEvent: GasRouterComponent::Event,
        #[flat]
        RouterEvent: RouterComponent::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        TokenRouterEvent: TokenRouterComponent::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        mailbox: ContractAddress,
        lockbox: ContractAddress,
        owner: ContractAddress,
        hook: ContractAddress,
        interchain_security_module: ContractAddress
    ) {
        self.ownable.initializer(owner);
        self
            .mailbox
            .initialize(mailbox, Option::Some(hook), Option::Some(interchain_security_module));
        let lockbox_dispatcher = IXERC20LockboxDispatcher { contract_address: lockbox };
        self.collateral.initialize(lockbox_dispatcher.erc20());
        let xerc20 = lockbox_dispatcher.xerc20();
        self.xerc20.write(IXERC20Dispatcher { contract_address: xerc20 });
        self.approve_lockbox();
    }

    impl HypXERC20LockboxImpl of super::IHypXERC20Lockbox<ContractState> {
        fn approve_lockbox(ref self: ContractState) {
            let lockbox_address = self.lockbox.read().contract_address;
            assert!(
                self.collateral.wrapped_token.read().approve(lockbox_address, BoundedInt::max()),
                "erc20 lockbox approve failed"
            );
            assert!(
                IERC20Dispatcher { contract_address: self.xerc20.read().contract_address }
                    .approve(lockbox_address, BoundedInt::max()),
                "xerc20 lockbox approve failed"
            );
        }
    }

    #[abi(embed_v0)]
    impl MessageRecipient of IMessageRecipient<ContractState> {
        fn handle(
            ref self: ContractState, origin: u32, sender: Option<ContractAddress>, message: Bytes
        ) {
            let amount = message.amount();
            let recipient = message.recipient();

            self._transfer_to(recipient, amount);

            self
                .token_router
                .emit(TokenRouterComponent::ReceivedTransferRemote { origin, recipient, amount, });
        }
    }

    #[abi(embed_v0)]
    impl TokenRouter of ITokenRouter<ContractState> {
        fn transfer_remote(
            ref self: ContractState,
            destination: u32,
            recipient: u256,
            amount_or_id: u256,
            value: u256,
            hook_metadata: Option<Bytes>,
            hook: Option<ContractAddress>
        ) -> u256 {
            let token_metadata = self._transfer_from_sender(amount_or_id);
            let token_message = TokenMessageTrait::format(recipient, amount_or_id, token_metadata);

            let mut message_id = 0;

            match hook_metadata {
                Option::Some(hook_metadata) => {
                    if !hook.is_some() {
                        panic!("Transfer remote invalid arguments, missing hook");
                    }

                    message_id = self
                        .router
                        ._Router_dispatch(
                            destination, value, token_message, hook_metadata, hook.unwrap()
                        );
                },
                Option::None => {
                    let hook_metadata = self.gas_router._Gas_router_hook_metadata(destination);
                    let hook = self.mailbox.get_hook();
                    message_id = self
                        .router
                        ._Router_dispatch(destination, value, token_message, hook_metadata, hook);
                }
            }

            self
                .token_router
                .emit(
                    TokenRouterComponent::SentTransferRemote {
                        destination, recipient, amount: amount_or_id,
                    }
                );

            message_id
        }
    }
    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _transfer_from_sender(ref self: ContractState, amount: u256) -> Bytes {
            self.collateral._transfer_from_sender(amount);

            self.lockbox.read().deposit(amount);

            self.xerc20.read().burn(starknet::get_contract_address(), amount);
            BytesTrait::new_empty()
        }

        fn _transfer_to(ref self: ContractState, recipient: u256, amount: u256) {
            self.xerc20.read().mint(starknet::get_contract_address(), amount);
            self.lockbox.read().withdraw_to(recipient, amount);
        }
    }
}


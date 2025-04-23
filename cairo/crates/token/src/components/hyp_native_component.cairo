#[starknet::interface]
pub trait IHypNative<TState> {
    fn receive(ref self: TState, amount: u256);
}

#[starknet::component]
pub mod HypNativeComponent {
    use alexandria_bytes::{Bytes, BytesTrait};
    use contracts::client::{
        gas_router_component::GasRouterComponent, mailboxclient_component::MailboxclientComponent,
        router_component::RouterComponent,
    };
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use starknet::ContractAddress;
    use token::components::token_router::{
        ITokenRouter, TokenRouterComponent, TokenRouterComponent::TokenRouterHooksTrait,
        TokenRouterTransferRemoteHookDefaultImpl,
    };

    #[storage]
    struct Storage {
        native_token: ERC20ABIDispatcher,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Donation: Donation,
    }

    #[derive(Drop, starknet::Event)]
    struct Donation {
        sender: ContractAddress,
        amount: u256,
    }

    pub mod Errors {
        pub const NATIVE_TOKEN_TRANSFER_FAILED: felt252 = 'Native token transfer failed';
        pub const NATIVE_TOKEN_TRANSFER_FROM_FAILED: felt252 = 'Native transfer_from failed';
    }

    #[embeddable_as(HypNativeImpl)]
    impl HypNative<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        +OwnableComponent::HasComponent<TContractState>,
        +RouterComponent::HasComponent<TContractState>,
        +GasRouterComponent::HasComponent<TContractState>,
        impl Mailboxclient: MailboxclientComponent::HasComponent<TContractState>,
        impl TokenRouter: TokenRouterComponent::HasComponent<TContractState>,
    > of super::IHypNative<ComponentState<TContractState>> {
        fn receive(ref self: ComponentState<TContractState>, amount: u256) {
            assert(
                self
                    .native_token
                    .read()
                    .transfer_from(
                        starknet::get_caller_address(), starknet::get_contract_address(), amount,
                    ),
                Errors::NATIVE_TOKEN_TRANSFER_FROM_FAILED,
            );

            self.emit(Donation { sender: starknet::get_caller_address(), amount });
        }
    }

    pub impl TokenRouterHooksImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        +MailboxclientComponent::HasComponent<TContractState>,
        +RouterComponent::HasComponent<TContractState>,
        +OwnableComponent::HasComponent<TContractState>,
        +GasRouterComponent::HasComponent<TContractState>,
        +TokenRouterComponent::HasComponent<TContractState>,
    > of TokenRouterHooksTrait<TContractState> {
        fn transfer_from_sender_hook(
            ref self: TokenRouterComponent::ComponentState<TContractState>, amount_or_id: u256,
        ) -> Bytes {
            let mut contract_state = TokenRouterComponent::HasComponent::get_contract_mut(ref self);
            let mut component_state = HasComponent::get_component_mut(ref contract_state);
            component_state._transfer_from_sender(amount_or_id)
        }

        fn transfer_to_hook(
            ref self: TokenRouterComponent::ComponentState<TContractState>,
            recipient: u256,
            amount_or_id: u256,
            metadata: Bytes,
        ) {
            let mut contract_state = TokenRouterComponent::HasComponent::get_contract_mut(ref self);
            let mut component_state = HasComponent::get_component_mut(ref contract_state);
            component_state._transfer_to(recipient, amount_or_id);
        }
    }

    #[embeddable_as(TokenRouterImpl)]
    impl TokenRouter<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl MailboxClient: MailboxclientComponent::HasComponent<TContractState>,
        impl Router: RouterComponent::HasComponent<TContractState>,
        +OwnableComponent::HasComponent<TContractState>,
        impl GasRouter: GasRouterComponent::HasComponent<TContractState>,
        impl TokenRouterComp: TokenRouterComponent::HasComponent<TContractState>,
    > of ITokenRouter<ComponentState<TContractState>> {
        fn transfer_remote(
            ref self: ComponentState<TContractState>,
            destination: u32,
            recipient: u256,
            amount_or_id: u256,
            value: u256,
            hook_metadata: Option<Bytes>,
            hook: Option<ContractAddress>,
        ) -> u256 {
            assert!(value >= amount_or_id, "Native: amount exceeds msg.value");
            let hook_payment = value - amount_or_id;

            let mut token_router_comp = get_dep_component_mut!(ref self, TokenRouterComp);
            TokenRouterTransferRemoteHookDefaultImpl::_transfer_remote(
                ref token_router_comp,
                destination,
                recipient,
                amount_or_id,
                hook_payment,
                Option::None,
                Option::None,
            )
        }
    }

    #[generate_trait]
    pub impl HypNativeInternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        +OwnableComponent::HasComponent<TContractState>,
        +RouterComponent::HasComponent<TContractState>,
        +GasRouterComponent::HasComponent<TContractState>,
        impl Mailboxclient: MailboxclientComponent::HasComponent<TContractState>,
        impl TokenRouter: TokenRouterComponent::HasComponent<TContractState>,
    > of InternalTrait<TContractState> {
        fn initialize(ref self: ComponentState<TContractState>, native_token: ContractAddress) {
            self.native_token.write(ERC20ABIDispatcher { contract_address: native_token });
        }

        fn _transfer_from_sender(ref self: ComponentState<TContractState>, amount: u256) -> Bytes {
            assert(
                self
                    .native_token
                    .read()
                    .transfer_from(
                        starknet::get_caller_address(), starknet::get_contract_address(), amount,
                    ),
                Errors::NATIVE_TOKEN_TRANSFER_FROM_FAILED,
            );
            BytesTrait::new_empty()
        }

        fn _transfer_to(ref self: ComponentState<TContractState>, recipient: u256, amount: u256) {
            let recipient_felt: felt252 = recipient.try_into().expect('u256 to felt failed');
            let recipient: ContractAddress = recipient_felt.try_into().unwrap();
            assert(
                self.native_token.read().transfer(recipient, amount),
                Errors::NATIVE_TOKEN_TRANSFER_FAILED,
            );
        }
    }
}

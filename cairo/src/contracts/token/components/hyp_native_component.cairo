use starknet::ContractAddress;

#[starknet::interface]
pub trait IHypNative<TState> {
    fn transfer_remote(
        ref self: TState, destination: u32, recipient: u256, amount: u256, mgs_value: u256
    ) -> u256;
    fn balance_of(self: @TState, account: ContractAddress) -> u256;
    fn receive(ref self: TState, amount: u256);
}

#[starknet::component]
pub mod HypNativeComponent {
    use alexandria_bytes::{Bytes, BytesTrait};
    use hyperlane_starknet::contracts::client::gas_router_component::{
        GasRouterComponent, GasRouterComponent::GasRouterInternalImpl,
    };
    use hyperlane_starknet::contracts::client::mailboxclient_component::{
        MailboxclientComponent, MailboxclientComponent::MailboxClientInternalImpl,
        MailboxclientComponent::MailboxClient
    };
    use hyperlane_starknet::contracts::client::router_component::{RouterComponent,};
    use hyperlane_starknet::contracts::token::components::token_router::{
        TokenRouterComponent, TokenRouterComponent::TokenRouterInternalImpl,
    };
    use openzeppelin::access::ownable::{
        OwnableComponent, OwnableComponent::InternalImpl, OwnableComponent::OwnableImpl
    };
    use openzeppelin::token::erc20::interface::{IERC20, IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};
    use starknet::ContractAddress;


    #[storage]
    struct Storage {
        eth_token: IERC20Dispatcher,
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
        fn transfer_remote(
            ref self: ComponentState<TContractState>,
            destination: u32,
            recipient: u256,
            amount: u256,
            mgs_value: u256
        ) -> u256 {
            assert!(mgs_value >= amount, "Native: amount exceeds msg.value");
            let hook_payment = mgs_value - amount;

            let mut token_router_comp = get_dep_component_mut!(ref self, TokenRouter);
            token_router_comp
                ._transfer_remote(
                    destination, recipient, amount, hook_payment, Option::None, Option::None
                )
        }

        fn balance_of(self: @ComponentState<TContractState>, account: ContractAddress) -> u256 {
            self.eth_token.read().balance_of(account)
        }

        fn receive(ref self: ComponentState<TContractState>, amount: u256) {
            self.eth_token.read().transfer(starknet::get_contract_address(), amount);

            self.emit(Donation { sender: starknet::get_caller_address(), amount });
        }
    }

    // overridess 
    #[generate_trait]
    pub impl HypNativeInternalImpl<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        fn transfer_from_sender(ref self: ComponentState<TContractState>, amount: u256) -> Bytes {
            BytesTrait::new_empty()
        }

        fn transfer_to(
            ref self: ComponentState<TContractState>, recepient: ContractAddress, amount: u256
        ) {
            self.eth_token.read().transfer(recepient, amount);
        }
    }
}

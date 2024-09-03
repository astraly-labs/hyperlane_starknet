use starknet::ContractAddress;

#[starknet::interface]
pub trait IHypNative<TState> {
    fn initialize(
        ref self: TState,
        hook: ContractAddress,
        interchain_security_module: ContractAddress,
        owner: ContractAddress
    );
    fn transfer_remote(
        ref self: TState, destination: u32, recipient: u256, amount: u256, mgs_value: u256
    ) -> u256;
    // fn balance_of(self: @TState, account: ContractAddress) -> u256;
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
        TokenRouterComponent::TokenRouterHooksTrait
    };
    use openzeppelin::access::ownable::{
        OwnableComponent, OwnableComponent::InternalImpl, OwnableComponent::OwnableImpl
    };
    use openzeppelin::token::erc20::{
        interface::{IERC20, IERC20Dispatcher, IERC20DispatcherTrait}, ERC20Component
    };
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
        +TokenRouterHooksTrait<TContractState>,
        +ERC20Component::HasComponent<TContractState>,
        impl Mailboxclient: MailboxclientComponent::HasComponent<TContractState>,
        impl TokenRouter: TokenRouterComponent::HasComponent<TContractState>,
    > of super::IHypNative<ComponentState<TContractState>> {
        fn initialize(
            ref self: ComponentState<TContractState>,
            hook: ContractAddress,
            interchain_security_module: ContractAddress,
            owner: ContractAddress
        ) {
            let mut mailboxclient_comp = get_dep_component_mut!(ref self, Mailboxclient);
            mailboxclient_comp._MailboxClient_initialize(hook, interchain_security_module, owner);
        }

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

        fn receive(ref self: ComponentState<TContractState>, amount: u256) {
            self.eth_token.read().transfer(starknet::get_contract_address(), amount);

            self.emit(Donation { sender: starknet::get_caller_address(), amount });
        }
    }
}

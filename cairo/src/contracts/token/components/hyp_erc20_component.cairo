use starknet::ContractAddress;

#[starknet::interface]
pub trait IHypErc20<TState> {
    fn decimals(self: @TState) -> u8;
}

#[starknet::component]
pub mod HypErc20Component {
    use hyperlane_starknet::contracts::client::gas_router_component::GasRouterComponent;
    use hyperlane_starknet::contracts::client::mailboxclient_component::MailboxclientComponent;
    use hyperlane_starknet::contracts::client::router_component::RouterComponent;
    use hyperlane_starknet::contracts::token::components::token_router::{
        TokenRouterComponent, TokenRouterComponent::TokenRouterInternalImpl
    };

    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::ERC20Component::{
        InternalImpl as ERC20InternalImpl, ERC20HooksTrait
    };
    use openzeppelin::token::erc20::ERC20Component;

    use starknet::ContractAddress;

    #[storage]
    struct Storage {
        decimals: u8,
    }

    #[embeddable_as(HypeErc20Impl)]
    impl HypErc20Impl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        +MailboxclientComponent::HasComponent<TContractState>,
        +RouterComponent::HasComponent<TContractState>,
        +OwnableComponent::HasComponent<TContractState>,
        +GasRouterComponent::HasComponent<TContractState>,
        +TokenRouterComponent::HasComponent<TContractState>,
        +ERC20HooksTrait<TContractState>,
        impl ERC20: ERC20Component::HasComponent<TContractState>
    > of super::IHypErc20<ComponentState<TContractState>> {
        fn decimals(self: @ComponentState<TContractState>) -> u8 {
            self.decimals.read()
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        +MailboxclientComponent::HasComponent<TContractState>,
        +RouterComponent::HasComponent<TContractState>,
        +OwnableComponent::HasComponent<TContractState>,
        +GasRouterComponent::HasComponent<TContractState>,
        impl TokenRouter: TokenRouterComponent::HasComponent<TContractState>,
        +ERC20HooksTrait<TContractState>,
        impl ERC20: ERC20Component::HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        fn initialize(
            ref self: ComponentState<TContractState>, decimals: u8, mailbox: ContractAddress
        ) {
            self.decimals.write(decimals);
            let mut token_router = get_dep_component_mut!(ref self, TokenRouter);
            token_router.initialize(mailbox)
        }

        fn transfer_from_sender(ref self: ComponentState<TContractState>, amount: u256) {
            let mut erc20 = get_dep_component_mut!(ref self, ERC20);
            erc20.burn(starknet::get_caller_address(), amount);
        }

        fn transfer_to_recipient(ref self: ComponentState<TContractState>, amount: u256) {
            let mut erc20 = get_dep_component_mut!(ref self, ERC20);
            erc20.mint(starknet::get_caller_address(), amount);
        }
    }
}

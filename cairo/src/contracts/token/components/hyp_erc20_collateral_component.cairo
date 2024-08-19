use starknet::ContractAddress;

#[starknet::interface]
pub trait IHypErc20Collateral<TState> {
    fn balance_of(self: @TState, account: ContractAddress) -> u256;
}

#[starknet::component]
pub mod HypErc20CollateralComponent {
    use hyperlane_starknet::contracts::client::gas_router_component::GasRouterComponent;
    use hyperlane_starknet::contracts::client::mailboxclient_component::{
        MailboxclientComponent, MailboxclientComponent::MailboxClientImpl
    };
    use hyperlane_starknet::contracts::client::router_component::RouterComponent;
    use hyperlane_starknet::contracts::token::components::token_router::{
        TokenRouterComponent, TokenRouterComponent::TokenRouterInternalImpl
    };

    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use starknet::ContractAddress;

    #[storage]
    struct Storage {
        wrapped_token: ERC20ABIDispatcher
    }

    #[embeddable_as(HypErc20CollateralImpl)]
    pub impl HypeErc20CollateralComponentImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        +MailboxclientComponent::HasComponent<TContractState>,
        +RouterComponent::HasComponent<TContractState>,
        +OwnableComponent::HasComponent<TContractState>,
        +GasRouterComponent::HasComponent<TContractState>,
        +TokenRouterComponent::HasComponent<TContractState>,
    > of super::IHypErc20Collateral<ComponentState<TContractState>> {
        fn balance_of(self: @ComponentState<TContractState>, account: ContractAddress) -> u256 {
            self.wrapped_token.read().balance_of(account)
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl Mailboxclient: MailboxclientComponent::HasComponent<TContractState>,
        +RouterComponent::HasComponent<TContractState>,
        +OwnableComponent::HasComponent<TContractState>,
        +GasRouterComponent::HasComponent<TContractState>,
        +TokenRouterComponent::HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        fn initialize(
            ref self: ComponentState<TContractState>,
            wrapped_token: ContractAddress,
            hook: ContractAddress,
            interchain_security_module: ContractAddress,
            owner: ContractAddress
        ) {
            self.wrapped_token.write(ERC20ABIDispatcher { contract_address: wrapped_token });
            let mut mailboxclient_comp = get_dep_component_mut!(ref self, Mailboxclient);
            mailboxclient_comp._MailboxClient_initialize(hook, interchain_security_module, owner);
        }

        fn transfer_from_sender(ref self: ComponentState<TContractState>, amount: u256) {
            self
                .wrapped_token
                .read()
                .transfer_from(
                    starknet::get_caller_address(), starknet::get_contract_address(), amount
                );
        }

        fn transfer_to(
            ref self: ComponentState<TContractState>, recipient: ContractAddress, amount: u256
        ) {
            self.wrapped_token.read().transfer(recipient, amount);
        }
    }
}

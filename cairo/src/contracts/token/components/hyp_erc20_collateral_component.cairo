use starknet::ContractAddress;

#[starknet::interface]
pub trait IHypErc20Collateral<TState> {
    fn balance_of(self: @TState, account: ContractAddress) -> u256;
}

#[starknet::component]
pub mod HypErc20CollateralComponent {
    use alexandria_bytes::{Bytes, BytesTrait};
    use hyperlane_starknet::contracts::client::gas_router_component::GasRouterComponent;
    use hyperlane_starknet::contracts::client::mailboxclient_component::{
        MailboxclientComponent, MailboxclientComponent::MailboxClientImpl
    };
    use hyperlane_starknet::contracts::client::router_component::RouterComponent;
    use hyperlane_starknet::contracts::token::components::token_router::{
        TokenRouterComponent, TokenRouterComponent::TokenRouterInternalImpl
    };

    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::ContractAddress;

    #[storage]
    struct Storage {
        wrapped_token: IERC20Dispatcher
    }

    #[embeddable_as(HypErc20CollateralImpl)]
    impl HypeErc20CollateralComponentImpl<
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
        fn initialize(ref self: ComponentState<TContractState>, wrapped_token: ContractAddress,) {
            self.wrapped_token.write(IERC20Dispatcher { contract_address: wrapped_token });
        }

        // overrides
        fn transfer_from_sender(ref self: ComponentState<TContractState>, amount: u256) -> Bytes {
            self
                .wrapped_token
                .read()
                .transfer_from(
                    starknet::get_caller_address(), starknet::get_contract_address(), amount
                );

            BytesTrait::new_empty()
        }

        fn transfer_to(
            ref self: ComponentState<TContractState>, recipient: ContractAddress, amount: u256
        ) {
            self.wrapped_token.read().transfer(recipient, amount);
        }
    }
}

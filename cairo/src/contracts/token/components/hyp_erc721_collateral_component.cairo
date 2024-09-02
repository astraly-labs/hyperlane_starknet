use starknet::ContractAddress;

#[starknet::interface]
pub trait IHypErc721Collateral<TState> {
    fn owner_of(self: @TState, token_id: u256) -> ContractAddress;
    fn balance_of(self: @TState, account: ContractAddress) -> u256;
}

#[starknet::component]
pub mod HypErc721CollateralComponent {
    use alexandria_bytes::{Bytes, BytesTrait};
    use hyperlane_starknet::contracts::client::mailboxclient_component::{
        MailboxclientComponent, MailboxclientComponent::MailboxClientInternalImpl,
        MailboxclientComponent::MailboxClient
    };
    use openzeppelin::access::ownable::{
        OwnableComponent, OwnableComponent::InternalImpl, OwnableComponent::OwnableImpl
    };
    use openzeppelin::token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};
    use starknet::ContractAddress;

    #[storage]
    struct Storage {
        wrapped_token: IERC721Dispatcher,
    }

    #[embeddable_as(HypErc721CollateralImpl)]
    impl HypErc721CollateralComponentImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        +OwnableComponent::HasComponent<TContractState>,
        impl Mailboxclient: MailboxclientComponent::HasComponent<TContractState>,
    > of super::IHypErc721Collateral<ComponentState<TContractState>> {
        fn owner_of(self: @ComponentState<TContractState>, token_id: u256) -> ContractAddress {
            self.wrapped_token.read().owner_of(token_id)
        }

        fn balance_of(self: @ComponentState<TContractState>, account: ContractAddress) -> u256 {
            self.wrapped_token.read().balance_of(account)
        }
    }

    #[generate_trait]
    impl HypErc721CollateralInternalImpl<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>
    > of InternalTrait<TContractState> {
        fn transfer_from_sender(ref self: ComponentState<TContractState>, token_id: u256) -> Bytes {
            self
                .wrapped_token
                .read()
                .transfer_from(
                    starknet::get_caller_address(), starknet::get_contract_address(), token_id
                );

            BytesTrait::new_empty()
        }

        fn transfer_to(
            ref self: ComponentState<TContractState>,
            recipient: ContractAddress,
            token_id: u256,
            calldata: Array<felt252>
        ) {
            self
                .wrapped_token
                .read()
                .safe_transfer_from(
                    starknet::get_contract_address(), recipient, token_id, calldata.span()
                );
        }
    }
}

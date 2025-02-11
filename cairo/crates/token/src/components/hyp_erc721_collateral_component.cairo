use starknet::ContractAddress;

#[starknet::interface]
pub trait IHypErc721Collateral<TState> {
    fn owner_of(self: @TState, token_id: u256) -> ContractAddress;
    fn balance_of(self: @TState, account: ContractAddress) -> u256;
    fn get_wrapped_token(self: @TState) -> ContractAddress;
}

#[starknet::component]
pub mod HypErc721CollateralComponent {
    use alexandria_bytes::{Bytes, BytesTrait};
    use contracts::client::{
        gas_router_component::GasRouterComponent, mailboxclient_component::MailboxclientComponent,
        router_component::RouterComponent,
    };
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc721::interface::{ERC721ABIDispatcher, ERC721ABIDispatcherTrait};
    use starknet::ContractAddress;
    use token::components::token_router::{
        TokenRouterComponent, TokenRouterComponent::TokenRouterHooksTrait,
    };

    #[storage]
    struct Storage {
        wrapped_token: ERC721ABIDispatcher,
    }

    #[embeddable_as(HypErc721CollateralImpl)]
    impl HypErc721CollateralComponentImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        +OwnableComponent::HasComponent<TContractState>,
        impl Mailboxclient: MailboxclientComponent::HasComponent<TContractState>,
    > of super::IHypErc721Collateral<ComponentState<TContractState>> {
        /// Returns the owner of a given ERC721 token ID.
        ///
        /// This function queries the wrapped ERC721 token contract to retrieve the address of the
        /// owner of the specified `token_id`.
        ///
        /// # Arguments
        ///
        /// * `token_id` - A `u256` representing the ID of the token whose owner is being queried.
        ///
        /// # Returns
        ///
        /// A `ContractAddress` representing the owner of the specified token.
        fn owner_of(self: @ComponentState<TContractState>, token_id: u256) -> ContractAddress {
            self.wrapped_token.read().owner_of(token_id)
        }

        /// Returns the balance of ERC721 tokens held by a given account.
        ///
        /// This function retrieves the number of ERC721 tokens held by the specified account by
        /// querying the wrapped ERC721 token contract.
        ///
        /// # Arguments
        ///
        /// * `account` - A `ContractAddress` representing the account whose balance is being
        /// queried.
        ///
        /// # Returns
        ///
        /// A `u256` representing the number of tokens held by the specified account.
        fn balance_of(self: @ComponentState<TContractState>, account: ContractAddress) -> u256 {
            self.wrapped_token.read().balance_of(account)
        }

        /// Returns the contract address of the wrapped ERC721 token.
        ///
        /// This function retrieves the contract address of the wrapped ERC721 token from the
        /// component's storage.
        ///
        /// # Returns
        ///
        /// A `ContractAddress` representing the address of the wrapped ERC721 token.
        fn get_wrapped_token(self: @ComponentState<TContractState>) -> ContractAddress {
            let wrapped_token: ERC721ABIDispatcher = self.wrapped_token.read();
            wrapped_token.contract_address
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

            component_state
                .wrapped_token
                .read()
                .transfer_from(
                    starknet::get_caller_address(), starknet::get_contract_address(), amount_or_id,
                );

            BytesTrait::new_empty()
        }

        fn transfer_to_hook(
            ref self: TokenRouterComponent::ComponentState<TContractState>,
            recipient: u256,
            amount_or_id: u256,
            metadata: Bytes,
        ) {
            let mut contract_state = TokenRouterComponent::HasComponent::get_contract_mut(ref self);
            let mut component_state = HasComponent::get_component_mut(ref contract_state);

            let recipient_felt: felt252 = recipient.try_into().expect('u256 to felt failed');
            let recipient: ContractAddress = recipient_felt.try_into().unwrap();

            let metadata_array_u128 = metadata.data();
            let mut metadata_array_felt252: Array<felt252> = array![];

            let len = metadata_array_u128.len();
            let mut i = 0;
            while i < len {
                let metadata_felt252: felt252 = (*metadata_array_u128.at(i))
                    .try_into()
                    .expect('u128 to felt failed');
                metadata_array_felt252.append(metadata_felt252);
                i = i + 1;
            };

            component_state
                .wrapped_token
                .read()
                .safe_transfer_from(
                    starknet::get_contract_address(),
                    recipient,
                    amount_or_id,
                    metadata_array_felt252.span(),
                );
        }
    }
}

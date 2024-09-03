use starknet::ContractAddress;

#[starknet::interface]
pub trait IHypErc721Collateral<TState> {
    fn initialize(
        ref self: TState,
        hook: ContractAddress,
        interchain_security_module: ContractAddress,
        owner: ContractAddress
    );
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
    use openzeppelin::token::erc721::interface::{ERC721ABIDispatcher, ERC721ABIDispatcherTrait};
    use starknet::ContractAddress;

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
        fn initialize(
            ref self: ComponentState<TContractState>,
            hook: ContractAddress,
            interchain_security_module: ContractAddress,
            owner: ContractAddress
        ) {
            let mut mailboxclient_comp = get_dep_component_mut!(ref self, Mailboxclient);
            mailboxclient_comp._MailboxClient_initialize(hook, interchain_security_module, owner);
        }

        fn owner_of(self: @ComponentState<TContractState>, token_id: u256) -> ContractAddress {
            self.wrapped_token.read().owner_of(token_id)
        }

        fn balance_of(self: @ComponentState<TContractState>, account: ContractAddress) -> u256 {
            self.wrapped_token.read().balance_of(account)
        }
    }
}

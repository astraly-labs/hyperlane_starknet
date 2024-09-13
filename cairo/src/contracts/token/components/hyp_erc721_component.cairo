use starknet::{ContractAddress, ClassHash};

#[starknet::interface]
pub trait IHypErc721<TState> {
    fn initialize(ref self: TState, mint_amount: u256, name: ByteArray, symbol: ByteArray,);
}

#[starknet::component]
pub mod HypErc721Component {
    use hyperlane_starknet::contracts::client::mailboxclient_component::{
        MailboxclientComponent, MailboxclientComponent::MailboxClientInternalImpl,
        MailboxclientComponent::MailboxClient
    };
    use openzeppelin::access::ownable::{
        OwnableComponent, OwnableComponent::InternalImpl as OwnableInternalImpl
    };
    use openzeppelin::introspection::src5::{
        SRC5Component, SRC5Component::SRC5Impl, SRC5Component::InternalTrait as SRC5InternalTrait
    };
    use openzeppelin::token::erc721::{
        ERC721Component, ERC721Component::ERC721Impl,
        ERC721Component::InternalTrait as ERC721InternalTrait, ERC721Component::ERC721HooksTrait,
    };

    use starknet::{ContractAddress, ClassHash};


    #[storage]
    struct Storage {}

    #[embeddable_as(HypErc721Impl)]
    impl HypErc721<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        +OwnableComponent::HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +ERC721Component::ERC721HooksTrait<TContractState>,
        impl Mailboxclient: MailboxclientComponent::HasComponent<TContractState>,
        impl ERC721: ERC721Component::HasComponent<TContractState>,
    > of super::IHypErc721<ComponentState<TContractState>> {
        /// Initializes the ERC721 token contract with a specified mint amount, name, and symbol.
        ///
        /// This function sets the name and symbol for the ERC721 token contract and mints the specified number
        /// of tokens to the caller's address. The initialization process ensures that the contract is set up
        /// with the given name, symbol, and initial minting operation.
        ///
        /// # Arguments
        ///
        /// * `mint_amount` - A `u256` representing the number of tokens to mint initially.
        /// * `name` - A `ByteArray` representing the name of the token.
        /// * `symbol` - A `ByteArray` representing the symbol (ticker) of the token.
        fn initialize(
            ref self: ComponentState<TContractState>,
            mint_amount: u256,
            name: ByteArray,
            symbol: ByteArray,
        ) {
            let mut erc721_comp = get_dep_component_mut!(ref self, ERC721);
            erc721_comp.initializer(name, symbol, "");

            let caller = starknet::get_caller_address();

            let mut i = 0;
            while i < mint_amount {
                erc721_comp.mint(caller, i.into());
                i += 1;
            };
        }
    }

    #[generate_trait]
    impl HypErc721InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +ERC721Component::ERC721HooksTrait<TContractState>,
        impl ERC721: ERC721Component::HasComponent<TContractState>,
    > of InternalTrait<TContractState> {
        /// Burns a token owned by the sender.
        ///
        /// This function ensures that the sender is the owner of the specified token before burning it.
        /// The token is permanently removed from the sender's balance.
        ///
        /// # Arguments
        ///
        /// * `token_id` - A `u256` representing the ID of the token to be burned.
        ///
        /// # Panics
        ///
        /// Panics if the caller is not the owner of the token.
        fn transfer_from_sender(ref self: ComponentState<TContractState>, token_id: u256) {
            let erc721_comp_read = get_dep_component!(@self, ERC721);
            assert!(
                erc721_comp_read.owner_of(token_id) == starknet::get_caller_address(),
                "Caller is not owner of token"
            );

            let mut erc721_comp_write = get_dep_component_mut!(ref self, ERC721);
            erc721_comp_write.burn(token_id);
        }

        /// Mints a token to a specified recipient.
        ///
        /// This function mints the specified token to the given recipient's address. The newly minted token
        /// will be transferred to the recipient.
        ///
        /// # Arguments
        ///
        /// * `recipient` - A `ContractAddress` representing the recipient's address.
        /// * `token_id` - A `u256` representing the ID of the token to be minted.
        fn transfer_to(
            ref self: ComponentState<TContractState>, recipient: ContractAddress, token_id: u256
        ) {
            let mut erc721_comp_write = get_dep_component_mut!(ref self, ERC721);
            erc721_comp_write.mint(recipient, token_id);
        }
    }
}

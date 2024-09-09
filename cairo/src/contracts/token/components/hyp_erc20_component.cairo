use starknet::ContractAddress;

#[starknet::interface]
pub trait IHypErc20<TState> {
    fn decimals(self: @TState) -> u8;
}

#[starknet::component]
pub mod HypErc20Component {
    use alexandria_bytes::{Bytes, BytesTrait};
    use hyperlane_starknet::contracts::client::gas_router_component::{
        GasRouterComponent,
        GasRouterComponent::{GasRouterInternalImpl, InternalTrait as GasRouterInternalTrait}
    };
    use hyperlane_starknet::contracts::client::mailboxclient_component::{
        MailboxclientComponent, MailboxclientComponent::MailboxClientImpl
    };
    use hyperlane_starknet::contracts::client::router_component::{
        RouterComponent,
        RouterComponent::{InternalTrait as RouterInternalTrait, RouterComponentInternalImpl}
    };
    use hyperlane_starknet::contracts::token::components::token_message::TokenMessageTrait;
    use hyperlane_starknet::contracts::token::components::token_router::{
        TokenRouterComponent, TokenRouterComponent::TokenRouterInternalImpl,
        TokenRouterComponent::TokenRouterHooksTrait
    };
    use hyperlane_starknet::contracts::token::interfaces::imessage_recipient::IMessageRecipient;
    use hyperlane_starknet::interfaces::IMailboxClient;
    use hyperlane_starknet::utils::utils::{U256TryIntoContractAddress};
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

    pub impl TokenRouterHooksImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        +MailboxclientComponent::HasComponent<TContractState>,
        +RouterComponent::HasComponent<TContractState>,
        +OwnableComponent::HasComponent<TContractState>,
        +GasRouterComponent::HasComponent<TContractState>,
        +TokenRouterComponent::HasComponent<TContractState>,
        +ERC20HooksTrait<TContractState>,
        +ERC20Component::HasComponent<TContractState>
    > of TokenRouterHooksTrait<TContractState> {
        fn transfer_from_sender_hook(
            ref self: TokenRouterComponent::ComponentState<TContractState>, amount_or_id: u256
        ) -> Bytes {
            let mut contract_state = TokenRouterComponent::HasComponent::get_contract_mut(ref self);
            let mut component_state = HasComponent::get_component_mut(ref contract_state);
            component_state._transfer_from_sender(amount_or_id)
        }

        fn transfer_to_hook(
            ref self: TokenRouterComponent::ComponentState<TContractState>,
            recipient: u256,
            amount_or_id: u256,
            metadata: Bytes
        ) {
            let mut contract_state = TokenRouterComponent::HasComponent::get_contract_mut(ref self);
            let mut component_state = HasComponent::get_component_mut(ref contract_state);
            component_state._transfer_to(recipient, amount_or_id);
        }
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
        +TokenRouterComponent::HasComponent<TContractState>,
        +ERC20HooksTrait<TContractState>,
        impl ERC20: ERC20Component::HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        fn initialize(ref self: ComponentState<TContractState>, decimals: u8) {
            self.decimals.write(decimals);
        }

        fn _transfer_from_sender(ref self: ComponentState<TContractState>, amount: u256) -> Bytes {
            println!("transfer_from_sender");
            println!("caller: {:?}", starknet::get_caller_address());
            let mut erc20 = get_dep_component_mut!(ref self, ERC20);
            erc20.burn(starknet::get_caller_address(), amount);
            println!("after burn");
            BytesTrait::new_empty()
        }

        fn _transfer_to(ref self: ComponentState<TContractState>, recipient: u256, amount: u256) {
            let mut erc20 = get_dep_component_mut!(ref self, ERC20);
            erc20.mint(recipient.try_into().expect('u256 to ContractAddress failed'), amount);
        }
    }
}

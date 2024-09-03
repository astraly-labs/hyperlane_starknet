#[starknet::interface]
pub trait IFastTokenRouter<TState> {
    fn fill_fast_transfer(
        ref self: TState,
        recipient: u256,
        amount: u256,
        fast_fee: u256,
        origin: u32,
        fast_transfer_id: u256
    );
    fn fast_transfer_remote(
        ref self: TState,
        destination: u32,
        recipient: u256,
        amount_or_id: u256,
        fast_fee: u256,
        value: u256
    ) -> u256;
}

#[starknet::component]
pub mod FastTokenRouterComponent {
    use alexandria_bytes::{Bytes, BytesTrait};
    use hyperlane_starknet::contracts::client::gas_router_component::{
        GasRouterComponent, GasRouterComponent::GasRouterInternalImpl
    };
    use hyperlane_starknet::contracts::client::mailboxclient_component::{
        MailboxclientComponent, MailboxclientComponent::MailboxClientInternalImpl,
        MailboxclientComponent::MailboxClient
    };
    use hyperlane_starknet::contracts::client::router_component::{
        RouterComponent, RouterComponent::RouterComponentInternalImpl, IRouter,
    };
    use hyperlane_starknet::contracts::token::components::token_message::TokenMessageTrait;
    use hyperlane_starknet::contracts::token::components::token_router::{
        TokenRouterComponent, TokenRouterComponent::TokenRouterInternalImpl,
        TokenRouterComponent::TokenRouterHooksTrait
    };
    use openzeppelin::access::ownable::{
        OwnableComponent, OwnableComponent::InternalImpl as OwnableInternalImpl
    };
    use starknet::ContractAddress;

    #[storage]
    struct Storage {
        fast_transfer_id: u256,
        filled_fast_transfers: LegacyMap<u256, ContractAddress>,
    }

    #[embeddable_as(FastTokenRouterImpl)]
    impl FastTokenRouter<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        +TokenRouterHooksTrait<TContractState>,
        impl MailBoxClient: MailboxclientComponent::HasComponent<TContractState>,
        impl Router: RouterComponent::HasComponent<TContractState>,
        impl Owner: OwnableComponent::HasComponent<TContractState>,
        impl GasRouter: GasRouterComponent::HasComponent<TContractState>,
        impl TokenRouter: TokenRouterComponent::HasComponent<TContractState>,
    > of super::IFastTokenRouter<ComponentState<TContractState>> {
        fn fill_fast_transfer(
            ref self: ComponentState<TContractState>,
            recipient: u256,
            amount: u256,
            fast_fee: u256,
            origin: u32,
            fast_transfer_id: u256
        ) {
            let filled_fast_transfer_key = self
                ._get_fast_transfers_key(origin, fast_transfer_id, amount, fast_fee, recipient);

            assert!(
                self
                    .filled_fast_transfers
                    .read(filled_fast_transfer_key) == starknet::contract_address_const::<0>(),
                "Fast transfer: request already filled"
            );

            let caller = starknet::get_caller_address();
            self.filled_fast_transfers.write(filled_fast_transfer_key, caller);

            self._fast_recieve_from(caller, amount - fast_fee);
            self._fast_transfer_to(recipient, amount - fast_fee);
        }

        fn fast_transfer_remote(
            ref self: ComponentState<TContractState>,
            destination: u32,
            recipient: u256,
            amount_or_id: u256,
            fast_fee: u256,
            value: u256,
        ) -> u256 {
            let mut gas_router_comp = get_dep_component_mut!(ref self, GasRouter);
            let mut mailbox_comp = get_dep_component_mut!(ref self, MailBoxClient);
            let mut token_router_comp = get_dep_component_mut!(ref self, TokenRouter);

            let fast_transfer_id = self.fast_transfer_id.read() + 1;
            self.fast_transfer_id.write(fast_transfer_id);

            let metadata = self
                ._fast_transfer_from_sender(amount_or_id, fast_fee, fast_transfer_id);

            let message_body = TokenMessageTrait::format(recipient, amount_or_id, metadata);
            let hook = mailbox_comp.get_hook();
            let message_id = gas_router_comp
                ._Gas_router_dispatch(destination, value, message_body, hook);

            token_router_comp
                .emit(
                    TokenRouterComponent::SentTransferRemote {
                        destination, recipient, amount: amount_or_id,
                    }
                );

            message_id
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        +TokenRouterHooksTrait<TContractState>,
        impl MailBoxClient: MailboxclientComponent::HasComponent<TContractState>,
        impl Router: RouterComponent::HasComponent<TContractState>,
        impl Owner: OwnableComponent::HasComponent<TContractState>,
        impl GasRouter: GasRouterComponent::HasComponent<TContractState>,
        impl TokenRouter: TokenRouterComponent::HasComponent<TContractState>,
    > of InternalTrait<TContractState> {
        // all needs to support override
        fn _handle(ref self: ComponentState<TContractState>, origin: u32, message: Bytes) {
            let mut token_router_comp = get_dep_component_mut!(ref self, TokenRouter);

            let recipient = message.recipient();
            let amount = message.amount();
            let metadata = message.metadata();

            self._transfer_to(recipient, amount, origin, metadata);

            token_router_comp
                .emit(TokenRouterComponent::ReceivedTransferRemote { origin, recipient, amount, });
        }

        fn _transfer_to(
            ref self: ComponentState<TContractState>,
            recipient: u256,
            amount: u256,
            origin: u32,
            metadata: Bytes
        ) {
            let token_recipient = self._get_token_recipient(recipient, amount, origin, metadata);

            self._fast_transfer_to(token_recipient, amount);
        }

        fn _fast_transfer_to(
            ref self: ComponentState<TContractState>, recipient: u256, amount: u256
        ) {}

        fn _fast_recieve_from(
            ref self: ComponentState<TContractState>, sender: ContractAddress, amount: u256
        ) {}

        fn _get_token_recipient(
            self: @ComponentState<TContractState>,
            recipient: u256,
            amount: u256,
            origin: u32,
            metadata: Bytes
        ) -> u256 {
            if metadata.size() == 0 {
                return recipient;
            }

            let (_, fast_fee) = metadata.read_u256(0);
            let (_, fast_transfer_id) = metadata.read_u256(2);

            let filler_address = self
                ._get_fast_transfers_key(origin, fast_transfer_id, amount, fast_fee, recipient);
            if filler_address == 0 {
                return filler_address;
            }

            recipient
        }

        fn _get_fast_transfers_key(
            self: @ComponentState<TContractState>,
            origin: u32,
            fast_transfer_id: u256,
            amount: u256,
            fast_fee: u256,
            recipient: u256
        ) -> u256 {
            let data = BytesTrait::new(
                9, // do we need this?
                array![
                    origin.into(),
                    fast_transfer_id.low,
                    fast_transfer_id.high,
                    amount.low,
                    amount.high,
                    fast_fee.low,
                    fast_fee.high,
                    recipient.low,
                    recipient.high
                ]
            );
            data.keccak()
        }

        fn _fast_transfer_from_sender(
            ref self: ComponentState<TContractState>,
            amount: u256,
            fast_fee: u256,
            fast_transfer_id: u256
        ) -> Bytes {
            self._fast_recieve_from(starknet::get_caller_address(), amount);
            BytesTrait::new(
                4, array![fast_fee.low, fast_fee.high, fast_transfer_id.low, fast_transfer_id.high]
            )
        }
    }
}

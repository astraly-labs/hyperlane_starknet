#[starknet::interface]
pub trait ITokenRouter<TState> {
    fn initialize(ref self: TState);
    fn transfer_remote(
        self: @TState, destination: u32, recipient: Array<u8>, amount_or_id: u256
    ) -> u256;
    fn transfer_remote_with_hook(
        self: @TState,
        destination: u32,
        // TODO: make this fixed size once we switch to 2.7.0
        recipient: Array<u8>,
        amount_or_id: u256,
        hook_metadata: u256,
        hook: u256
    ) -> u256;
    fn balance_of(self: @TState, account: u256) -> u256;
}

#[starknet::component]
pub mod TokenRouter {
    use starknet::ContractAddress;
    #[storage]
    struct Storage {}

    fn constructor() {}

    impl TokenRouterImpl<
        TContractState, +HasComponent<TContractState>,
    > of super::ITokenRouter<ComponentState<TContractState>> {
        fn initialize(ref self: ComponentState<TContractState>) {}

        fn transfer_remote(
            self: @ComponentState<TContractState>,
            destination: u32,
            // TODO: make this fixed size once we switch to 2.7.0
            recipient: Array<u8>,
            amount_or_id: u256
        ) -> u256 {
            0
        }

        fn transfer_remote_with_hook(
            self: @ComponentState<TContractState>,
            destination: u32,
            // TODO: make this fixed size once we switch to 2.7.0
            recipient: Array<u8>,
            amount_or_id: u256,
            hook_metadata: u256,
            hook: u256
        ) -> u256 {
            0
        }

        fn balance_of(self: @ComponentState<TContractState>, account: u256) -> u256 {
            0
        }
    }

    #[generate_trait]
    impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        fn _transfer_remote(
            ref self: ComponentState<TContractState>,
            destination: u32,
            // TODO: make this fixed size once we switch to 2.7.0
            recipient: Array<u8>,
            amount_or_id: u256,
            value: u256,
            hook_metadata: Option<Array<u8>>,
            hook: Option<ContractAddress>
        ) -> u256 {
            0
        }

        fn _transfer_from_sender(
            ref self: ComponentState<TContractState>, amount_or_id: u256
        ) -> u256 {
            0
        }

        fn _handle(ref self: ComponentState<TContractState>, origin: u32, message: u256) {}

        fn _transfer_to(
            ref self: ComponentState<TContractState>,
            recipient: ContractAddress,
            amount_or_id: u256,
            metadata: Array<u8>
        ) {}
    }
}


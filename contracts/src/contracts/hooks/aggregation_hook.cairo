#[starknet::contract]
pub mod aggregation_hook {
    use alexandria_bytes::{Bytes, BytesTrait};
    use hyperlane_starknet::contracts::hooks::libs::standard_hook_metadata::standard_hook_metadata::{
        StandardHookMetadata, VARIANT,
    };
    use hyperlane_starknet::contracts::libs::message::Message;
    use hyperlane_starknet::interfaces::{
        IPostDispatchHook, Types, IPostDispatchHookDispatcher, IPostDispatchHookDispatcherTrait, ETH_ADDRESS
    };
    use starknet::{ContractAddress, get_contract_address};
    use openzeppelin::token::erc20::interface::{IERC20, IERC20Dispatcher, IERC20DispatcherTrait};

    #[storage]
    struct Storage {
        hooks: LegacyMap::<usize, ContractAddress>,
        hook_count: usize,
    }

    mod Errors {
        pub const INVALID_METADATA_VARIANT: felt252 = 'Invalid metadata variant';
        pub const INSUFFICIENT_BALANCE: felt252 = 'Insufficient balance';
        pub const INSUFFICIENT_FUNDS: felt252 = 'Insufficient funds';
    }

    #[constructor]
    fn constructor(ref self: ContractState, hooks: Span<ContractAddress>) {
        let mut i = 0;
        loop {
            if i >= hooks.len() {
                break;
            }

            self.hooks.write(i, *hooks.at(i));
            i += 1;
        };

        self.hook_count.write(hooks.len());
    }

    #[abi(embed_v0)]
    impl IPostDispatchHookImpl of IPostDispatchHook<ContractState> {
        fn hook_type(self: @ContractState) -> Types {
            Types::AGGREGATION(())
        }

        fn supports_metadata(self: @ContractState, _metadata: Bytes) -> bool {
            _metadata.size() == 0 || StandardHookMetadata::variant(_metadata) == VARIANT.into()
        }

        fn post_dispatch(
            ref self: ContractState, _metadata: Bytes, _message: Message, _fee_amount: u256
        ) {
            assert(self.supports_metadata(_metadata.clone()), Errors::INVALID_METADATA_VARIANT);

            let token_dispatcher = IERC20Dispatcher { contract_address: ETH_ADDRESS() };
            let agg_hook_address = get_contract_address();

            let balance = token_dispatcher.balance_of(agg_hook_address);
            assert(balance >= _fee_amount, Errors::INSUFFICIENT_BALANCE);

            let hook_count = self.hook_count.read();
            let mut remaining_fees = _fee_amount;
            let mut i = 0_usize;
            loop {
                if i >= hook_count {
                    break;
                }

                let hook_address = self.hooks.read(i);
                let hook_dispatcher = IPostDispatchHookDispatcher { contract_address: hook_address };

                let quote = hook_dispatcher.quote_dispatch(_metadata.clone(), _message.clone());
                assert(quote <= remaining_fees, Errors::INSUFFICIENT_FUNDS);

                token_dispatcher.transfer(hook_address, quote);
                remaining_fees -= quote;

                IPostDispatchHookDispatcher { contract_address: hook_address }
                    .post_dispatch(_metadata.clone(), _message.clone(), quote);

                i += 1;
            };
        }

        fn quote_dispatch(ref self: ContractState, _metadata: Bytes, _message: Message) -> u256 {
            assert(self.supports_metadata(_metadata.clone()), Errors::INVALID_METADATA_VARIANT);

            let hook_count = self.hook_count.read();
            let mut i = 0_usize;
            let mut total = 0_u256;
            loop {
                if i >= hook_count {
                    break;
                }

                let contract_address = self.hooks.read(i);

                let value = IPostDispatchHookDispatcher { contract_address }
                    .quote_dispatch(_metadata.clone(), _message.clone());

                total += value;
                i += 1;
            };

            total
        }
    }
}

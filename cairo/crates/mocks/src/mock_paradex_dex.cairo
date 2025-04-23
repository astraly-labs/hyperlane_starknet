use contracts::utils::utils::U256TryIntoContractAddress;
use core::starknet::event::EventEmitter;
use openzeppelin::token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
use starknet::ContractAddress;
use starknet::get_contract_address;


#[starknet::interface]
pub trait IMockParadexDex<TContractState> {
    fn deposit_on_behalf_of(
        ref self: TContractState,
        recipient: ContractAddress,
        token_address: ContractAddress,
        amount: felt252,
    ) -> felt252;

    fn set_hyperlane_token(ref self: TContractState, token_address: ContractAddress);

    fn get_token_asset_balance(
        self: @TContractState, account: ContractAddress, token_address: ContractAddress,
    ) -> felt252;
}

#[starknet::contract]
pub mod MockParadexDex {
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use super::*;

    pub mod Errors {
        pub const CALLER_NOT_HYPERLANE: felt252 = 'Caller not hyperlane';
        pub const INSUFFICIENT_ALLOWANCE: felt252 = 'Insufficient allowance';
    }

    #[storage]
    struct Storage {
        hyperlane_token_address: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        DepositSuccess: DepositSuccess,
    }

    #[derive(Drop, starknet::Event)]
    pub struct DepositSuccess {
        pub token: ContractAddress,
        pub recipient: ContractAddress,
        pub amount: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {}


    #[abi(embed_v0)]
    impl IMockParadexDexImpl of super::IMockParadexDex<ContractState> {
        fn set_hyperlane_token(ref self: ContractState, token_address: ContractAddress) {
            self.hyperlane_token_address.write(token_address);
        }

        fn deposit_on_behalf_of(
            ref self: ContractState,
            recipient: ContractAddress,
            token_address: ContractAddress,
            amount: felt252,
        ) -> felt252 {
            // check if the sender is the hyperlane token address
            assert(
                starknet::get_caller_address() != self.hyperlane_token_address.read(),
                Errors::CALLER_NOT_HYPERLANE,
            );

            let token_dispatcher = ERC20ABIDispatcher { contract_address: token_address };
            // check for the allowance of the token
            let allowance = token_dispatcher
                .allowance(starknet::get_caller_address(), get_contract_address());
            let amount_u256: u256 = amount.try_into().unwrap();
            assert(allowance >= amount_u256, Errors::INSUFFICIENT_ALLOWANCE);
            token_dispatcher
                .transfer_from(
                    starknet::get_caller_address(), starknet::get_contract_address(), amount_u256,
                );

            self
                .emit(
                    DepositSuccess {
                        token: token_address, recipient: recipient, amount: amount_u256,
                    },
                );
            return amount;
        }

        fn get_token_asset_balance(
            self: @ContractState, account: ContractAddress, token_address: ContractAddress,
        ) -> felt252 {
            let token_dispatcher = ERC20ABIDispatcher { contract_address: token_address };
            token_dispatcher.balance_of(starknet::get_contract_address()).try_into().unwrap()
        }
    }
}

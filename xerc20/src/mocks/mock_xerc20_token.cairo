///! Mock XERC20 token that emit events to check has been made or not.
///! Emit events for the following functions.
///! - mint
///! - burn
///! - set_limits
///! - set_lockbox
#[starknet::contract]
pub mod MockXERC20 {
    use crate::xerc20::interface::{Bridge, BridgeParameters, XERC20ABI};
    use openzeppelin_token::erc20::erc20::ERC20Component;
    use starknet::ContractAddress;

    pub const U256MAX_DIV_2: u256 = core::num::traits::Bounded::MAX / 2;

    #[storage]
    pub struct Storage {}

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        LockboxSet: LockboxSet,
        BridgeLimitsSet: BridgeLimitsSet,
        Transfer: ERC20Component::Transfer,
    }

    #[derive(Drop, starknet::Event)]
    pub struct LockboxSet {
        pub lockbox: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct BridgeLimitsSet {
        pub minting_limit: u256,
        pub burning_limit: u256,
        #[key]
        pub bridge: ContractAddress,
    }

    #[abi(embed_v0)]
    pub impl XERC20ABIImpl of XERC20ABI<ContractState> {
        fn set_lockbox(ref self: ContractState, lockbox: ContractAddress) {
            self.emit(LockboxSet { lockbox });
        }

        fn set_limits(
            ref self: ContractState,
            bridge: ContractAddress,
            minting_limit: u256,
            burning_limit: u256,
        ) {
            self.emit(BridgeLimitsSet { minting_limit, burning_limit, bridge });
        }

        fn mint(ref self: ContractState, user: ContractAddress, amount: u256) {
            self
                .emit(
                    ERC20Component::Transfer {
                        from: starknet::contract_address_const::<0>(), to: user, value: amount,
                    },
                );
        }


        fn burn(ref self: ContractState, user: ContractAddress, amount: u256) {
            self
                .emit(
                    ERC20Component::Transfer {
                        from: user, to: starknet::contract_address_const::<0>(), value: amount,
                    },
                );
        }

        fn minting_max_limit_of(self: @ContractState, minter: ContractAddress) -> u256 {
            U256MAX_DIV_2
        }

        fn burning_max_limit_of(self: @ContractState, bridge: ContractAddress) -> u256 {
            U256MAX_DIV_2
        }

        fn minting_current_limit_of(self: @ContractState, minter: ContractAddress) -> u256 {
            U256MAX_DIV_2
        }

        fn burning_current_limit_of(self: @ContractState, bridge: ContractAddress) -> u256 {
            U256MAX_DIV_2
        }

        fn lockbox(self: @ContractState) -> ContractAddress {
            starknet::contract_address_const::<'LOCKBOX'>()
        }

        fn factory(self: @ContractState) -> ContractAddress {
            starknet::contract_address_const::<'FACTORY'>()
        }

        fn get_bridge(self: @ContractState, bridge: ContractAddress) -> Bridge {
            let minter_params = BridgeParameters {
                max_limit: U256MAX_DIV_2,
                current_limit: U256MAX_DIV_2,
                timestamp: 0,
                rate_per_second: U256MAX_DIV_2,
            };
            let burner_params = BridgeParameters {
                max_limit: U256MAX_DIV_2,
                current_limit: U256MAX_DIV_2,
                timestamp: 0,
                rate_per_second: U256MAX_DIV_2,
            };

            Bridge { minter_params, burner_params }
        }
    }
}


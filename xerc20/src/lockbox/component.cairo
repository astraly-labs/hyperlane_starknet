#[starknet::component]
pub mod XERC20LockboxComponent {
    use crate::{
        lockbox::interface::{IXERC20Lockbox, IXERC20LockboxGetters},
        xerc20::interface::{IXERC20Dispatcher, IXERC20DispatcherTrait},
    };
    use openzeppelin_token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    #[storage]
    pub struct Storage {
        xerc20: IXERC20Dispatcher,
        erc20: ERC20ABIDispatcher,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Deposit: Deposit,
        Withdraw: Withdraw,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Deposit {
        pub sender: ContractAddress,
        pub amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Withdraw {
        pub sender: ContractAddress,
        pub amount: u256,
    }

    pub mod Errors {
        pub const ERC20_TRANSFER_FAILED: felt252 = 'ERC20 transfer failed';
        pub const ERC20_TRANSFER_FROM_FAILED: felt252 = 'ERC20 transfer_from failed';
    }

    #[embeddable_as(XERC20Lockbox)]
    pub impl XERC20LockboxImpl<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of IXERC20Lockbox<ComponentState<TContractState>> {
        /// Deposit ERC20 tokens into the lockbox.
        ///
        /// # Arguments
        ///
        /// - `amount` An `u256` representing the amount of tokens to deposit.
        fn deposit(ref self: ComponentState<TContractState>, amount: u256) {
            self._deposit(starknet::get_caller_address(), amount);
        }

        /// Deposit ERC20 tokens into the lockbox, and send the XERC20 to a user.
        ///
        /// # Arguments
        ///
        /// - `user` A `ContractAddress` representing the address to send the XERC20 to.
        /// - `amount` An `u256` representing the amount of tokens to deposit.
        fn deposit_to(ref self: ComponentState<TContractState>, to: ContractAddress, amount: u256) {
            self._deposit(to, amount);
        }

        /// Withdraw ERC20 tokens from the lockbox.
        ///
        /// # Arguments
        ///
        /// - `amount` An `u256` representing the amount of tokens to withdraw.
        fn withdraw(ref self: ComponentState<TContractState>, amount: u256) {
            self._withdraw(starknet::get_caller_address(), amount);
        }

        /// Withdraw ERC20 tokens from the lockbox, and sends it to user.
        ///
        /// # Arguments
        ///
        /// - `user` A `ContractAddress` to send the ERC20 tokens to.
        /// - `amount` An `u256` representing the amount of tokens to withdraw.
        fn withdraw_to(
            ref self: ComponentState<TContractState>, to: ContractAddress, amount: u256,
        ) {
            self._withdraw(to, amount);
        }
    }

    #[embeddable_as(XERC20LockboxGettersImpl)]
    pub impl XERC20LockboxGetters<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of IXERC20LockboxGetters<ComponentState<TContractState>> {
        /// Returns `ContractAddress` representing the XERC20 token of this contract.
        fn xerc20(self: @ComponentState<TContractState>) -> ContractAddress {
            self.xerc20.read().contract_address
        }

        /// Returns `ContractAddress` representing the ERC20 token of this contract.
        fn erc20(self: @ComponentState<TContractState>) -> ContractAddress {
            self.erc20.read().contract_address
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        /// Initializer of this component.
        fn initialize(
            ref self: ComponentState<TContractState>,
            xerc20: ContractAddress,
            erc20: ContractAddress,
        ) {
            self.xerc20.write(IXERC20Dispatcher { contract_address: xerc20 });
            self.erc20.write(ERC20ABIDispatcher { contract_address: erc20 });
        }

        /// Internal function that burns the xerc20 tokens then transfer the erc20 token to
        /// recipient.
        fn _withdraw(ref self: ComponentState<TContractState>, to: ContractAddress, amount: u256) {
            self.emit(Withdraw { sender: to, amount });
            self.xerc20.read().burn(starknet::get_caller_address(), amount);
            assert(self.erc20.read().transfer(to, amount), Errors::ERC20_TRANSFER_FAILED);
        }

        /// Internal function that locks erc20 token in lockbox then mints xerc20 tokens.
        fn _deposit(ref self: ComponentState<TContractState>, to: ContractAddress, amount: u256) {
            assert(
                self
                    .erc20
                    .read()
                    .transfer_from(
                        starknet::get_caller_address(), starknet::get_contract_address(), amount,
                    ),
                Errors::ERC20_TRANSFER_FROM_FAILED,
            );
            self.xerc20.read().mint(to, amount);
            self.emit(Deposit { sender: to, amount: amount });
        }
    }
}


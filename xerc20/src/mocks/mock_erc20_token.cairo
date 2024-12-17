///! Mock ERC20 token that emits events on transfers and approvals.
///! Used for checking call has been made or not.
///! Returns 0 for balance_of, allowance, total_supply.
#[starknet::contract]
mod MockErc20 {
    use openzeppelin_token::erc20::interface::IERC20;
    use starknet::ContractAddress;

    #[storage]
    pub struct Storage {}

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    pub enum Event {
        Transfer: Transfer,
        Approval: Approval,
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct Transfer {
        #[key]
        pub from: ContractAddress,
        #[key]
        pub to: ContractAddress,
        pub value: u256,
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct Approval {
        #[key]
        pub owner: ContractAddress,
        #[key]
        pub spender: ContractAddress,
        pub value: u256,
    }

    #[abi(embed_v0)]
    impl ERC20Impl of IERC20<ContractState> {
        fn total_supply(self: @ContractState) -> u256 {
            0
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            0
        }

        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress,
        ) -> u256 {
            0
        }

        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            self
                .emit(
                    Transfer { from: starknet::get_caller_address(), to: recipient, value: amount },
                );
            true
        }

        fn transfer_from(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
        ) -> bool {
            self.emit(Transfer { from: sender, to: recipient, value: amount });
            true
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            self.emit(Approval { owner: starknet::get_caller_address(), spender, value: amount });
            true
        }
    }
}

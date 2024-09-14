use alexandria_bytes::Bytes;

#[starknet::interface]
pub trait ITestISM<TContractState> {
    fn set_verify(ref self: TContractState, verify: bool);
    fn verify(ref self: TContractState, calldata: Bytes, _calldata: Bytes) -> bool;
}

#[starknet::contract]
pub mod TestISM {
    use alexandria_bytes::Bytes;
    use super::ITestISMDispatcher;

    #[storage]
    struct Storage {
        verify_result: bool,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.verify_result.write(true);
    }

    #[abi(embed_v0)]
    impl TestISMImpl of super::ITestISM<ContractState> {
        fn set_verify(ref self: ContractState, verify: bool) {
            self.verify_result.write(verify);
        }

        fn verify(ref self: ContractState, calldata: Bytes, _calldata: Bytes) -> bool {
            self.verify_result.read()
        }
    }
}

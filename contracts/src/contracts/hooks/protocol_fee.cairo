#[starknet::contract]
pub mod protocol_fee {
    use alexandria_bytes::{Bytes, BytesTrait, BytesStore};
    use hyperlane_starknet::contracts::hooks::libs::standard_hook_metadata::standard_hook_metadata::{
        StandardHookMetadata, VARIANT
    };
    use hyperlane_starknet::contracts::libs::message::Message;
    use hyperlane_starknet::interfaces::{IPostDispatchHook, Types, IProtocolFee};
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::interface::{IERC20, IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::upgrades::{interface::IUpgradeable, upgradeable::UpgradeableComponent};
    use starknet::{
        ContractAddress, contract_address_const, get_caller_address, get_contract_address
    };
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        max_protocol_fee: u256,
        protocol_fee: u256,
        beneficiary: ContractAddress,
        fee_token: ContractAddress,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
    }

    mod Errors {
        pub const INVALID_METADATA_VARIANT: felt252 = 'Invalid metadata variant';
        pub const INVALID_BENEFICARY: felt252 = 'Invalid beneficiary';
        pub const EXCEEDS_MAX_PROTOCOL_FEE: felt252 = 'Exceeds max protocol fee';
        pub const INSUFFICIENT_BALANCE: felt252 = 'Insufficient balance';
        pub const INSUFFICIENT_ALLOWANCE: felt252 = 'Insufficient allowance';
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        _max_protocol_fee: u256,
        _protocol_fee: u256,
        _beneficiary: ContractAddress,
        _owner: ContractAddress,
        _token_address: ContractAddress
    ) {
        self.max_protocol_fee.write(_max_protocol_fee);
        self._set_protocol_fee(_protocol_fee);
        self._set_beneficiary(_beneficiary);
        self.ownable.initializer(_owner);
        self.fee_token.write(_token_address);
    }

    #[abi(embed_v0)]
    impl IPostDispatchHookImpl of IPostDispatchHook<ContractState> {

        fn hook_type(self: @ContractState) -> Types {
            Types::PROTOCOL_FEE(())
        }
        
        fn supports_metadata(self: @ContractState, _metadata: Bytes) -> bool {
            _metadata.size() == 0 || StandardHookMetadata::variant(_metadata) == VARIANT.into()
        }

        fn post_dispatch(ref self: ContractState, _metadata: Bytes, _message: Message) {
            assert(self.supports_metadata(_metadata.clone()), Errors::INVALID_METADATA_VARIANT);
            self._post_dispatch(_metadata, _message);
        }

        fn quote_dispatch(ref self: ContractState, _metadata: Bytes, _message: Message) -> u256 {
            assert(self.supports_metadata(_metadata.clone()), Errors::INVALID_METADATA_VARIANT);
            self._quote_dispatch(_metadata, _message)
        }
    }

    #[abi(embed_v0)]
    pub impl IProtocolFeeImpl of IProtocolFee<ContractState> {

        fn get_protocol_fee(self: @ContractState) -> u256 {
            self.protocol_fee.read()
        }

        fn set_protocol_fee(ref self: ContractState, _protocol_fee: u256) {
            self.ownable.assert_only_owner();
            self._set_protocol_fee(_protocol_fee);
        }

        fn get_beneficiary(self: @ContractState) -> ContractAddress {
            self.beneficiary.read()
        }

        fn set_beneficiary(ref self: ContractState, _beneficiary: ContractAddress) {
            self.ownable.assert_only_owner();
            self._set_beneficiary(_beneficiary);
        }


        fn collect_protocol_fees(ref self: ContractState) {
            let token_dispatcher = IERC20Dispatcher { contract_address: self.fee_token.read() };
            let contract_address = get_contract_address();
            let balance = token_dispatcher.balance_of(contract_address);
            assert(balance != 0, Errors::INSUFFICIENT_BALANCE);
            token_dispatcher.transfer(self.beneficiary.read(), balance);
        }
    }


    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _post_dispatch(ref self: ContractState, _metadata: Bytes, _message: Message) {
            let token_dispatcher = IERC20Dispatcher { contract_address: self.fee_token.read() };
            let caller_address = get_caller_address();
            let contract_address = get_contract_address();
            let user_balance = token_dispatcher.balance_of(caller_address);
            assert(user_balance != 0, Errors::INSUFFICIENT_BALANCE);
            let protocol_fee = self.protocol_fee.read();
            assert(
                token_dispatcher.allowance(caller_address, contract_address) >= protocol_fee,
                Errors::INSUFFICIENT_ALLOWANCE
            );
            token_dispatcher.transfer_from(caller_address, contract_address, protocol_fee);
        }

        fn _quote_dispatch(ref self: ContractState, _metadata: Bytes, _message: Message) -> u256 {
            self.protocol_fee.read()
        }

        fn _set_protocol_fee(ref self: ContractState, _protocol_fee: u256) {
            assert(_protocol_fee <= self.max_protocol_fee.read(), Errors::EXCEEDS_MAX_PROTOCOL_FEE);
            self.protocol_fee.write(_protocol_fee);
        }
        fn _set_beneficiary(ref self: ContractState, _beneficiary: ContractAddress) {
            assert(_beneficiary != contract_address_const::<0>(), Errors::INVALID_BENEFICARY);
            self.beneficiary.write(_beneficiary);
        }
    }
}

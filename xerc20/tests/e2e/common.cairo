use core::hash::{HashStateExTrait, HashStateTrait};
use core::poseidon::PoseidonTrait;
use crate::common::E18;
use openzeppelin_token::erc20::interface::ERC20ABIDispatcher;
use openzeppelin_token::erc20::snip12_utils::permit::Permit;
use openzeppelin_utils::cryptography::{
    interface::{
        INoncesDispatcher, INoncesDispatcherTrait, ISNIP12MetadataDispatcher,
        ISNIP12MetadataDispatcherTrait,
    },
    snip12::{StarknetDomain, StructHash},
};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, load, map_entry_address,
    signature::{
        KeyPair, KeyPairTrait, SignerTrait,
        stark_curve::{StarkCurveKeyPairImpl, StarkCurveSignerImpl, StarkCurveVerifierImpl},
    },
    start_cheat_caller_address, stop_cheat_caller_address, store,
};
use starknet::ContractAddress;
use starknet::account::AccountContractDispatcher;
use xerc20::{
    factory::interface::{IXERC20FactoryDispatcher, IXERC20FactoryDispatcherTrait},
    lockbox::interface::XERC20LockboxABIDispatcher, xerc20::interface::XERC20ABIDispatcher,
};

pub fn DAI() -> ContractAddress {
    starknet::contract_address_const::<
        0x05574eb6b8789a91466f902c380d978e472db68170ff82a5b650b95a58ddf4ad,
    >()
}

pub fn DAI_NAME() -> ByteArray {
    "Dai Stablecoin"
}

pub fn DAI_SYMBOL() -> ByteArray {
    "DAI"
}

#[derive(Drop)]
pub struct Setup {
    pub factory: IXERC20FactoryDispatcher,
    pub xerc20: XERC20ABIDispatcher,
    pub lockbox: XERC20LockboxABIDispatcher,
    pub owner: ContractAddress,
    pub user: ContractAddress,
    pub user_account: AccountContractDispatcher,
    pub user_key_pair: KeyPair<felt252, felt252>,
    pub dai: ERC20ABIDispatcher,
    pub test_minter: ContractAddress,
}

pub fn setup_base() -> Setup {
    let owner = starknet::contract_address_const::<1>();
    let user_account_contract = declare("MockAccount").unwrap().contract_class();
    // set deployer key and account
    let user_key_pair = KeyPairTrait::<felt252, felt252>::generate();
    let (user_account_address, _) = user_account_contract
        .deploy(@array![user_key_pair.public_key])
        .unwrap();
    let test_minter = starknet::contract_address_const::<123_456_789>();
    let dai_address = DAI();
    let dai_dispatcher = ERC20ABIDispatcher { contract_address: dai_address };
    /// Declare implementations
    let xerc20_class_hash = declare("XERC20").unwrap().contract_class().class_hash;
    let xerc20_lockbox_class_hash = declare("XERC20Lockbox").unwrap().contract_class().class_hash;
    /// Declare and deploy factory
    let factory_contract = declare("XERC20Factory").unwrap().contract_class();
    let mut ctor_calldata: Array<felt252> = array![];
    xerc20_class_hash.serialize(ref ctor_calldata);
    xerc20_lockbox_class_hash.serialize(ref ctor_calldata);
    owner.serialize(ref ctor_calldata);
    let (factory_address, _) = factory_contract.deploy(@ctor_calldata).unwrap();
    let factory_dispatcher = IXERC20FactoryDispatcher { contract_address: factory_address };
    /// Deploy xerc20 token
    let minter_limits = array![100 * E18].span();
    let burner_limits = array![50 * E18].span();
    let bridges = array![test_minter].span();

    start_cheat_caller_address(factory_address, owner);
    let xerc20_address = factory_dispatcher
        .deploy_xerc20(DAI_NAME(), DAI_SYMBOL(), minter_limits, burner_limits, bridges);
    let xerc20 = XERC20ABIDispatcher { contract_address: xerc20_address };
    /// Deploy lockbox
    let lockbox_address = factory_dispatcher.deploy_lockbox(xerc20_address, dai_address);
    let lockbox = XERC20LockboxABIDispatcher { contract_address: lockbox_address };
    stop_cheat_caller_address(factory_address);

    Setup {
        factory: factory_dispatcher,
        xerc20,
        lockbox,
        owner,
        user: user_account_address,
        user_account: AccountContractDispatcher { contract_address: user_account_address },
        user_key_pair,
        dai: dai_dispatcher,
        test_minter,
    }
}

pub fn mint_dai(to: ContractAddress, amount: u256) {
    let dai_address = DAI();
    // Increment balance
    let mut loaded_balance = load(
        dai_address, map_entry_address(selector!("ERC20_balances"), array![to.into()].span()), 2,
    )
        .span();
    let balance = Serde::<u256>::deserialize(ref loaded_balance).unwrap();

    let mut serialized_new_balance: Array<felt252> = array![];
    (balance + amount).serialize(ref serialized_new_balance);
    store(
        dai_address,
        map_entry_address(selector!("ERC20_balances"), array![to.into()].span()),
        serialized_new_balance.span(),
    );
    // Increment total supply
    let mut loaded_total_supply = load(dai_address, selector!("ERC20_total_supply"), 2).span();
    let total_supply = Serde::<u256>::deserialize(ref loaded_total_supply).unwrap();

    let mut serialized_new_total_supply: Array<felt252> = array![];
    (total_supply + amount).serialize(ref serialized_new_total_supply);
    store(dai_address, selector!("ERC20_total_supply"), serialized_new_total_supply.span());
}

pub fn prepare_permit_signature(
    setup: @Setup, spender: ContractAddress, amount: u256, deadline: u64,
) -> Span<felt252> {
    let snip12_metadata_dispatcher = ISNIP12MetadataDispatcher {
        contract_address: *setup.xerc20.contract_address,
    };
    let (name, version) = snip12_metadata_dispatcher.snip12_metadata();
    let sn_domain = StarknetDomain {
        name: name,
        version: version,
        chain_id: starknet::get_tx_info().unbox().chain_id,
        revision: 1,
    };
    let nonces_dispatcher = INoncesDispatcher { contract_address: *setup.xerc20.contract_address };
    let nonce = nonces_dispatcher.nonces(*setup.user);
    let permit = Permit {
        token: *setup.xerc20.contract_address,
        spender: *setup.owner,
        amount: amount,
        nonce,
        deadline,
    };
    let msg_hash = PoseidonTrait::new()
        .update_with('StarkNet Message')
        .update_with(sn_domain.hash_struct())
        .update_with(*setup.user)
        .update_with(permit.hash_struct())
        .finalize();

    let (r, s) = (*setup.user_key_pair).sign(msg_hash).unwrap();
    array![r, s].span()
}

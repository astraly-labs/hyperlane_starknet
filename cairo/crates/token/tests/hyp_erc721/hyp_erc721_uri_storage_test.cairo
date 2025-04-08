use alexandria_bytes::BytesTrait;
use contracts::hooks::libs::standard_hook_metadata::standard_hook_metadata::VARIANT;
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use super::common::{
    DESTINATION, FEE_CAP, IHypErc721TestDispatcher, IHypErc721TestDispatcherTrait, INITIAL_SUPPLY,
    NAME, SYMBOL, Setup, URI, deploy_remote_token, perform_remote_transfer, setup,
    test_transfer_with_hook_specified,
};

fn setup_erc721_uri_storage() -> Setup {
    let mut setup = setup();

    let contract = declare("MockHypERC721URIStorage").unwrap().contract_class();
    let mut calldata: Array<felt252> = array![];
    setup.local_mailbox.contract_address.serialize(ref calldata);
    INITIAL_SUPPLY.serialize(ref calldata);
    NAME().serialize(ref calldata);
    SYMBOL().serialize(ref calldata);
    setup.noop_hook.contract_address.serialize(ref calldata);
    setup.default_ism.serialize(ref calldata);
    starknet::get_contract_address().serialize(ref calldata);
    let (hyp_erc721_uri_storage, _) = contract.deploy(@calldata).unwrap();
    let hyp_erc721_uri_storage = IHypErc721TestDispatcher {
        contract_address: hyp_erc721_uri_storage,
    };

    hyp_erc721_uri_storage.set_token_uri(0, URI());
    let remote_token_address: felt252 = setup.remote_token.contract_address.into();
    hyp_erc721_uri_storage.enroll_remote_router(DESTINATION, remote_token_address.into());

    setup.local_token = hyp_erc721_uri_storage;

    setup
}

#[test]
#[should_panic]
fn test_erc721_uri_storage_remote_transfer_revert_burned() {
    let setup = setup_erc721_uri_storage();

    let setup = deploy_remote_token(setup, false);
    perform_remote_transfer(@setup, 2500, 0);

    let balance = setup.local_token.balance_of(starknet::get_contract_address());
    assert_eq!(balance, INITIAL_SUPPLY - 1);

    let uri = setup.local_token.token_uri(0);
    assert_eq!(uri, URI());
}

#[test]
fn test_erc721_uri_storage_remote_transfer() {
    let setup = setup_erc721_uri_storage();

    let setup = deploy_remote_token(setup, false);
    perform_remote_transfer(@setup, 2500, 0);

    let balance = setup.local_token.balance_of(starknet::get_contract_address());
    assert_eq!(balance, INITIAL_SUPPLY - 1);
}

#[test]
#[fuzzer]
fn test_fuzz_erc721_uri_storage_remote_transfer_with_hook_specified(mut fee: u256, metadata: u256) {
    let fee = fee % FEE_CAP;
    let mut metadata_bytes = BytesTrait::new_empty();
    metadata_bytes.append_u16(VARIANT);
    metadata_bytes.append_u256(metadata);

    let mut setup = setup_erc721_uri_storage();
    let setup = deploy_remote_token(setup, false);
    test_transfer_with_hook_specified(@setup, 0, fee, metadata_bytes);
    assert_eq!(setup.local_token.balance_of(starknet::get_contract_address()), INITIAL_SUPPLY - 1);
}


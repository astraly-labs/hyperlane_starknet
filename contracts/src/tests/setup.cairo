use alexandria_bytes::{Bytes, BytesTrait};
use alexandria_data_structures::array_ext::ArrayTraitExt;
use core::result::ResultTrait;
use hyperlane_starknet::contracts::libs::multisig::merkleroot_ism_metadata::merkleroot_ism_metadata::MERKLE_PROOF_ITERATION;
use hyperlane_starknet::interfaces::{
    IMailboxDispatcher, IMailboxDispatcherTrait, IMessageRecipientDispatcher,
    IMessageRecipientDispatcherTrait, IInterchainSecurityModule,
    IInterchainSecurityModuleDispatcher, IInterchainSecurityModuleDispatcherTrait,
    IValidatorAnnounceDispatcher, IValidatorAnnounceDispatcherTrait, IMailboxClientDispatcher,
    IMailboxClientDispatcherTrait, IAggregationDispatcher, IAggregationDispatcherTrait,
    IValidatorConfigurationDispatcher, IMerkleTreeHookDispatcher, IMerkleTreeHookDispatcherTrait,
    IAggregation, IPostDispatchHookDispatcher, IProtocolFeeDispatcher,
    IPostDispatchHookDispatcherTrait, IProtocolFeeDispatcherTrait, IMockValidatorAnnounceDispatcher,
    ISpecifiesInterchainSecurityModuleDispatcher, ISpecifiesInterchainSecurityModuleDispatcherTrait,
    IRoutingIsmDispatcher, IRoutingIsmDispatcherTrait, IDomainRoutingIsmDispatcher,
    IDomainRoutingIsmDispatcherTrait
};
use openzeppelin::account::utils::signature::EthSignature;
use openzeppelin::token::erc20::interface::{IERC20, IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{
    declare, ContractClassTrait, CheatTarget, EventSpy, EventAssertions, spy_events, SpyOn
};
use starknet::secp256_trait::Signature;


use starknet::{ContractAddress, contract_address_const, EthAddress};

pub const LOCAL_DOMAIN: u32 = 534352;
pub const DESTINATION_DOMAIN: u32 = 9841001;
pub const MAX_PROTOCOL_FEE: u256 = 1000000000;
pub const PROTOCOL_FEE: u256 = 1000000;
pub const INITIAL_SUPPLY: u256 = 10000000000;


pub fn OWNER() -> ContractAddress {
    contract_address_const::<'OWNER'>()
}

pub fn NEW_OWNER() -> ContractAddress {
    contract_address_const::<'NEW_OWNER'>()
}

pub fn VALID_OWNER() -> ContractAddress {
    contract_address_const::<0x1a4bcca63b5e8a46da3abe2080f75c16c18467d5838f00b375d9ba4c7c313dd>()
}

pub fn VALID_RECIPIENT() -> ContractAddress {
    contract_address_const::<0x1d35915d0abec0a28990198bb32aa570e681e7eb41a001c0094c7c36a712671>()
}

pub fn DEFAULT_ISM() -> ContractAddress {
    contract_address_const::<'DEFAULT_ISM'>()
}

pub fn DEFAULT_HOOK() -> ContractAddress {
    contract_address_const::<'DEFAULT_HOOK'>()
}

pub fn REQUIRED_HOOK() -> ContractAddress {
    contract_address_const::<'REQUIRED_HOOK'>()
}

pub fn NEW_DEFAULT_ISM() -> ContractAddress {
    contract_address_const::<'NEW_DEFAULT_ISM'>()
}

pub fn NEW_DEFAULT_HOOK() -> ContractAddress {
    contract_address_const::<'NEW_DEFAULT_HOOK'>()
}

pub fn NEW_REQUIRED_HOOK() -> ContractAddress {
    contract_address_const::<'NEW_REQUIRED_HOOK'>()
}

pub fn RECIPIENT_ADDRESS() -> ContractAddress {
    contract_address_const::<'RECIPIENT_ADDRESS'>()
}

pub fn VALIDATOR_ADDRESS_1() -> EthAddress {
    'VALIDATOR_ADDRESS_1'.try_into().unwrap()
}

pub fn VALIDATOR_ADDRESS_2() -> EthAddress {
    'VALIDATOR_ADDRESS_2'.try_into().unwrap()
}

pub fn BENEFICIARY() -> ContractAddress {
    'BENEFICIARY'.try_into().unwrap()
}

pub fn MAILBOX() -> ContractAddress {
    'MAILBOX'.try_into().unwrap()
}

pub fn MAILBOX_CLIENT() -> ContractAddress {
    'MAILBOX_CLIENT'.try_into().unwrap()
}

pub fn TEST_PROOF() -> Span<u256> {
    array![
        0x09020304050607080910111213141516,
        0x01020304050607080920111213141516,
        0x01020304050607080910000000000000,
        0x02010304050607080910111213141516,
        0x03000000000000000000000000000000,
        0x09020304050607080910111213141516,
        0x01020304050607080920111213141516,
        0x01020304050607080910000000000000,
        0x02010304050607080910111213141516,
        0x03000000000000000000000000000000,
        0x09020304050607080910111213141516,
        0x01020304050607080920111213141516,
        0x01020304050607080910000000000000,
        0x02010304050607080910111213141516,
        0x03000000000000000000000000000000,
        0x09020304050607080910111213141516,
        0x01020304050607080920111213141516,
        0x01020304050607080910000000000000,
        0x02010304050607080910111213141516,
        0x03000000000000000000000000000000,
        0x09020304050607080910111213141516,
        0x01020304050607080920111213141516,
        0x01020304050607080910000000000000,
        0x02010304050607080910111213141516,
        0x03000000000000000000000000000000,
        0x09020304050607080910111213141516,
        0x01020304050607080920111213141516,
        0x01020304050607080910000000000000,
        0x02010304050607080910111213141516,
        0x03000000000000000000000000000000,
        0x09020304050607080910111213141516,
        0x01020304050607080920111213141516,
    ]
        .span()
}
pub fn setup() -> (
    IMailboxDispatcher, EventSpy, IPostDispatchHookDispatcher, IInterchainSecurityModuleDispatcher
) {
    let mailbox_class = declare("mailbox").unwrap();
    let mock_hook = setup_mock_hook();
    let mock_ism = setup_mock_ism();
    mailbox_class
        .deploy_at(
            @array![
                LOCAL_DOMAIN.into(),
                OWNER().into(),
                mock_ism.contract_address.into(),
                mock_hook.contract_address.into(),
                mock_hook.contract_address.into()
            ],
            MAILBOX()
        )
        .unwrap();
    let mut spy = spy_events(SpyOn::One(MAILBOX()));
    (IMailboxDispatcher { contract_address: MAILBOX() }, spy, mock_hook, mock_ism)
}

pub fn mock_setup(
    mock_ism_address: ContractAddress
) -> (IMessageRecipientDispatcher, ISpecifiesInterchainSecurityModuleDispatcher,) {
    let message_recipient_class = declare("message_recipient").unwrap();
    let (message_recipient_addr, _) = message_recipient_class
        .deploy(@array![mock_ism_address.into()])
        .unwrap();
    (
        IMessageRecipientDispatcher { contract_address: message_recipient_addr },
        ISpecifiesInterchainSecurityModuleDispatcher { contract_address: message_recipient_addr },
    )
}

pub fn setup_mock_ism() -> IInterchainSecurityModuleDispatcher {
    let mock_ism = declare("ism").unwrap();
    let (mock_ism_addr, _) = mock_ism.deploy(@array![]).unwrap();
    IInterchainSecurityModuleDispatcher { contract_address: mock_ism_addr }
}
pub fn setup_messageid_multisig_ism() -> (
    IInterchainSecurityModuleDispatcher, IValidatorConfigurationDispatcher
) {
    let messageid_multisig_class = declare("messageid_multisig_ism").unwrap();

    let (messageid_multisig_addr, _) = messageid_multisig_class
        .deploy(@array![OWNER().into()])
        .unwrap();
    (
        IInterchainSecurityModuleDispatcher { contract_address: messageid_multisig_addr },
        IValidatorConfigurationDispatcher { contract_address: messageid_multisig_addr }
    )
}


pub fn setup_merkleroot_multisig_ism() -> (
    IInterchainSecurityModuleDispatcher, IValidatorConfigurationDispatcher
) {
    let merkleroot_multisig_class = declare("merkleroot_multisig_ism").unwrap();

    let (merkleroot_multisig_addr, _) = merkleroot_multisig_class
        .deploy(@array![OWNER().into()])
        .unwrap();
    (
        IInterchainSecurityModuleDispatcher { contract_address: merkleroot_multisig_addr },
        IValidatorConfigurationDispatcher { contract_address: merkleroot_multisig_addr }
    )
}


pub fn setup_mailbox_client() -> IMailboxClientDispatcher {
    let (mailbox, _, _, _) = setup();
    let mailboxclient_class = declare("mailboxclient").unwrap();
    let res = mailboxclient_class
        .deploy_at(@array![mailbox.contract_address.into(), OWNER().into()], MAILBOX_CLIENT());
    if (res.is_err()) {
        panic(res.unwrap_err());
    }
    let (mailboxclient_addr, _) = res.unwrap();
    IMailboxClientDispatcher { contract_address: mailboxclient_addr }
}

pub fn setup_default_fallback_routing_ism() -> (
    IInterchainSecurityModuleDispatcher, IRoutingIsmDispatcher, IDomainRoutingIsmDispatcher
) {
    let (mailbox, _, _, _) = setup();
    let default_fallback_routing_ism = declare("default_fallback_routing_ism").unwrap();
    let (default_fallback_routing_ism_addr, _) = default_fallback_routing_ism
        .deploy(@array![OWNER().into(), mailbox.contract_address.into()])
        .unwrap();
    (
        IInterchainSecurityModuleDispatcher { contract_address: default_fallback_routing_ism_addr },
        IRoutingIsmDispatcher { contract_address: default_fallback_routing_ism_addr },
        IDomainRoutingIsmDispatcher { contract_address: default_fallback_routing_ism_addr }
    )
}

pub fn setup_domain_routing_ism() -> (
    IInterchainSecurityModuleDispatcher, IRoutingIsmDispatcher, IDomainRoutingIsmDispatcher
) {
    let domain_routing_ism = declare("domain_routing_ism").unwrap();
    let (domain_routing_ism_addr, _) = domain_routing_ism.deploy(@array![OWNER().into()]).unwrap();
    (
        IInterchainSecurityModuleDispatcher { contract_address: domain_routing_ism_addr },
        IRoutingIsmDispatcher { contract_address: domain_routing_ism_addr },
        IDomainRoutingIsmDispatcher { contract_address: domain_routing_ism_addr }
    )
}

pub fn setup_validator_announce() -> (IValidatorAnnounceDispatcher, EventSpy) {
    let validator_announce_class = declare("validator_announce").unwrap();
    let (mailbox, _, _, _) = setup();
    let (validator_announce_addr, _) = validator_announce_class
        .deploy(@array![mailbox.contract_address.into()])
        .unwrap();
    let mut spy = spy_events(SpyOn::One(validator_announce_addr));
    (IValidatorAnnounceDispatcher { contract_address: validator_announce_addr }, spy)
}

pub fn setup_mock_validator_announce(
    mailbox_address: ContractAddress, domain: u32
) -> IMockValidatorAnnounceDispatcher {
    let validator_announce_class = declare("mock_validator_announce").unwrap();
    let (validator_announce_addr, _) = validator_announce_class
        .deploy(@array![mailbox_address.into(), domain.into()])
        .unwrap();
    IMockValidatorAnnounceDispatcher { contract_address: validator_announce_addr }
}

pub fn setup_aggregation() -> IAggregationDispatcher {
    let aggregation_class = declare("aggregation").unwrap();
    let (aggregation_addr, _) = aggregation_class.deploy(@array![OWNER().into()]).unwrap();
    IAggregationDispatcher { contract_address: aggregation_addr }
}

pub fn setup_merkle_tree_hook() -> (
    IMerkleTreeHookDispatcher, IPostDispatchHookDispatcher, EventSpy
) {
    let (mailbox, _, _, _) = setup();
    let merkle_tree_hook_class = declare("merkle_tree_hook").unwrap();
    let res = merkle_tree_hook_class
        .deploy(@array![mailbox.contract_address.into(), OWNER().into()]);
    if (res.is_err()) {
        panic(res.unwrap_err());
    }
    let (merkle_tree_hook_addr, _) = res.unwrap();
    let mut spy = spy_events(SpyOn::One(merkle_tree_hook_addr));

    (
        IMerkleTreeHookDispatcher { contract_address: merkle_tree_hook_addr },
        IPostDispatchHookDispatcher { contract_address: merkle_tree_hook_addr },
        spy
    )
}

pub fn setup_mock_hook() -> IPostDispatchHookDispatcher {
    let mock_hook = declare("hook").unwrap();
    let (mock_hook_addr, _) = mock_hook.deploy(@array![]).unwrap();
    IPostDispatchHookDispatcher { contract_address: mock_hook_addr }
}


pub fn build_messageid_metadata(origin_merkle_tree_hook: u256, root: u256, index: u32) -> Bytes {
    let y_parity = 0x01;
    let (_, _, signatures) = get_message_and_signature();
    let mut metadata = BytesTrait::new_empty();
    metadata.append_u256(origin_merkle_tree_hook);
    metadata.append_u256(root);
    metadata.append_u32(index);
    let mut cur_idx = 0;
    loop {
        if (cur_idx == signatures.len()) {
            break ();
        }
        metadata.append_u256(*signatures.at(cur_idx).r);
        metadata.append_u256(*signatures.at(cur_idx).s);
        metadata.append_u8(y_parity);
        cur_idx += 1;
    };
    metadata
}

// Configuration from the main cairo repo: https://github.com/starkware-libs/cairo/blob/main/corelib/src/test/secp256k1_test.cairo
pub fn get_message_and_signature() -> (u256, Array<EthAddress>, Array<EthSignature>) {
    let msg_hash = 0xD12359855E2143AC1FA8145D294BB63926C9536014F68BB99896845C54949E8C;
    let validators_array: Array<EthAddress> = array![
        0xaafc175eedf5126e9c46c69f6d1412f83879703a.try_into().unwrap(),
        0x8b12e6fe8dc2701618ccaa9f0f2f543f225c1c41.try_into().unwrap(),
        0xa058aea5289617da6b0658067c5b8d6324e728fc.try_into().unwrap(),
        0xf398501b08cf2c388d228337b0de6b880b259f8b.try_into().unwrap(),
        0xa18be291c7db8d30bc6796f52a9a71f75652c309.try_into().unwrap()
    ];
    let signatures = array![
        EthSignature {
            r: 0x83db08d4e1590714aef8600f5f1e3c967ab6a3b9f93bb4242de0306510e688ea,
            s: 0x0af5d1d51ea7e51a291789ff4866a1e36bc4134d956870799380d2d71f5dbf3d,
        },
        EthSignature {
            r: 0xf81a5dd3f871ad2d27a3b538e73663d723f8263fb3d289514346d43d000175f5,
            s: 0x083df770623e9ae52a7bb154473961e24664bb003bdfdba6100fb5e540875ce1,
        },
        EthSignature {
            r: 0x76b194f951f94492ca582dab63dc413b9ac1ca9992c22bc2186439e9ab8fdd3c,
            s: 0x62a6a6f402edaa53e9bdc715070a61edb0d98d4e14e182f60bdd4ae932b40b29,
        },
        EthSignature {
            r: 0x35932eefd85897d868aaacd4ba7aee81a2384e42ba062133f6d37fdfebf94ad4,
            s: 0x78cce49db96ee27c3f461800388ac95101476605baa64a194b7dd4d56d2d4a4d,
        },
        EthSignature {
            r: 0x6b38d4353d69396e91c57542254348d16459d448ab887574e9476a6ff76d49a1,
            s: 0x3527627295bde423d7d799afef22affac4f00c70a5b651ad14c8879aeb9b6e03,
        }
    ];

    (msg_hash, validators_array, signatures)
}


pub fn build_merkle_metadata(
    origin_merkle_tree_hook: u256, message_index: u32, signed_index: u32, signed_message_id: u256
) -> Bytes {
    let proof = TEST_PROOF();
    let y_parity = 0x01;
    let (_, _, signatures) = get_merkle_message_and_signature();
    let mut metadata = BytesTrait::new_empty();
    metadata.append_u256(origin_merkle_tree_hook);
    metadata.append_u32(message_index);
    metadata.append_u256(signed_message_id);
    let mut cur_idx = 0;
    loop {
        if (cur_idx == MERKLE_PROOF_ITERATION) {
            break ();
        }
        metadata.append_u256(*proof.at(cur_idx));
        cur_idx += 1;
    };
    metadata.append_u32(signed_index);
    cur_idx = 0;
    loop {
        if (cur_idx == signatures.len()) {
            break ();
        }
        metadata.append_u256(*signatures.at(cur_idx).r);
        metadata.append_u256(*signatures.at(cur_idx).s);
        metadata.append_u8(y_parity);
        cur_idx += 1;
    };
    metadata
}
// Configuration from the main cairo repo: https://github.com/starkware-libs/cairo/blob/main/corelib/src/test/secp256k1_test.cairo
pub fn get_merkle_message_and_signature() -> (u256, Array<EthAddress>, Array<EthSignature>) {
    let msg_hash = 0x313C6A1725B61343B5B6A7882D194FAD12DCED93308CF5531AFAD1E78493396F;
    let validators_array: Array<EthAddress> = array![
        0x91bd769ffc38bed78b931c3d972ba06697916985.try_into().unwrap(),
        0x06071f400ed67eb4a895adcc32e0c5b8ae88ae44.try_into().unwrap(),
        0x18d48ab0f718ffe4c8019e00c92f737c22efbe0c.try_into().unwrap(),
        0xe800d496ac3ba56b2ff975bce3602b9f6ab90895.try_into().unwrap(),
        0x57d8e0df524faa4a31602a78299b6ae023e45fed.try_into().unwrap()
    ];
    let signatures = array![
        EthSignature {
            r: 0x83db08d4e1590714aef8600f5f1e3c967ab6a3b9f93bb4242de0306510e688ea,
            s: 0x0af5d1d51ea7e51a291789ff4866a1e36bc4134d956870799380d2d71f5dbf3d,
        },
        EthSignature {
            r: 0xf81a5dd3f871ad2d27a3b538e73663d723f8263fb3d289514346d43d000175f5,
            s: 0x083df770623e9ae52a7bb154473961e24664bb003bdfdba6100fb5e540875ce1,
        },
        EthSignature {
            r: 0x76b194f951f94492ca582dab63dc413b9ac1ca9992c22bc2186439e9ab8fdd3c,
            s: 0x62a6a6f402edaa53e9bdc715070a61edb0d98d4e14e182f60bdd4ae932b40b29,
        },
        EthSignature {
            r: 0x35932eefd85897d868aaacd4ba7aee81a2384e42ba062133f6d37fdfebf94ad4,
            s: 0x78cce49db96ee27c3f461800388ac95101476605baa64a194b7dd4d56d2d4a4d,
        },
        EthSignature {
            r: 0x6b38d4353d69396e91c57542254348d16459d448ab887574e9476a6ff76d49a1,
            s: 0x3527627295bde423d7d799afef22affac4f00c70a5b651ad14c8879aeb9b6e03,
        }
    ];

    (msg_hash, validators_array, signatures)
}


pub fn setup_protocol_fee() -> (
    IERC20Dispatcher, IProtocolFeeDispatcher, IPostDispatchHookDispatcher
) {
    let fee_token_class = declare("mock_fee_token").unwrap();
    let (fee_token_addr, _) = fee_token_class
        .deploy(@array![INITIAL_SUPPLY.low.into(), INITIAL_SUPPLY.high.into(), OWNER().into()])
        .unwrap();
    let protocol_fee_class = declare("protocol_fee").unwrap();
    let (protocol_fee_addr, _) = protocol_fee_class
        .deploy(
            @array![
                MAX_PROTOCOL_FEE.low.into(),
                MAX_PROTOCOL_FEE.high.into(),
                PROTOCOL_FEE.low.into(),
                PROTOCOL_FEE.high.into(),
                BENEFICIARY().into(),
                OWNER().into(),
                fee_token_addr.into()
            ]
        )
        .unwrap();
    (
        IERC20Dispatcher { contract_address: fee_token_addr },
        IProtocolFeeDispatcher { contract_address: protocol_fee_addr },
        IPostDispatchHookDispatcher { contract_address: protocol_fee_addr }
    )
}

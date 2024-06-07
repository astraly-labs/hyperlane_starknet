use core::result::ResultTrait;
use hyperlane_starknet::interfaces::{
    IMailboxDispatcher, IMailboxDispatcherTrait, IMessageRecipientDispatcher,
    IMessageRecipientDispatcherTrait, IInterchainSecurityModule,
    IInterchainSecurityModuleDispatcher, IInterchainSecurityModuleDispatcherTrait,
    IValidatorAnnounceDispatcher, IValidatorAnnounceDispatcherTrait, IMailboxClientDispatcher,
    IMailboxClientDispatcherTrait, IAggregationDispatcher, IAggregationDispatcherTrait,
    IValidatorConfigurationDispatcher, IMerkleTreeHookDispatcher, IMerkleTreeHookDispatcherTrait,
    IAggregation, IPostDispatchHookDispatcher, IProtocolFeeDispatcher,
    IPostDispatchHookDispatcherTrait, IProtocolFeeDispatcherTrait, IMockValidatorAnnounceDispatcher
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


pub fn setup() -> (IMailboxDispatcher, EventSpy) {
    let mailbox_class = declare("mailbox").unwrap();
    let (mailbox_addr, _) = mailbox_class
        .deploy(@array![LOCAL_DOMAIN.into(), OWNER().into()])
        .unwrap();
    let mut spy = spy_events(SpyOn::One(mailbox_addr));
    (IMailboxDispatcher { contract_address: mailbox_addr }, spy)
}

pub fn mock_setup() -> IMessageRecipientDispatcher {
    let message_recipient_class = declare("message_recipient").unwrap();

    let (message_recipient_addr, _) = message_recipient_class.deploy(@array![]).unwrap();
    IMessageRecipientDispatcher { contract_address: message_recipient_addr }
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

pub fn setup_mailbox_client() -> IMailboxClientDispatcher {
    let (mailbox, _) = setup();
    let mailboxclient_class = declare("mailboxclient").unwrap();
    let (mailboxclient_addr, _) = mailboxclient_class
        .deploy(@array![mailbox.contract_address.into(), OWNER().into()])
        .unwrap();
    IMailboxClientDispatcher { contract_address: mailboxclient_addr }
}

pub fn setup_validator_announce() -> IValidatorAnnounceDispatcher {
    let validator_announce_class = declare("validator_announce").unwrap();
    let mailboxclient = setup_mailbox_client();
    let (validator_announce_addr, _) = validator_announce_class
        .deploy(@array![mailboxclient.contract_address.into()])
        .unwrap();
    IValidatorAnnounceDispatcher { contract_address: validator_announce_addr }
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

pub fn setup_merkle_tree_hook() -> IMerkleTreeHookDispatcher {
    let merkle_tree_hook_class = declare("merkle_tree_hook").unwrap();
    let mailboxclient = setup_mailbox_client();
    let (merkle_tree_hook_addr, _) = merkle_tree_hook_class
        .deploy(@array![mailboxclient.contract_address.into()])
        .unwrap();
    IMerkleTreeHookDispatcher { contract_address: merkle_tree_hook_addr }
}

// Configuration from the main cairo repo: https://github.com/starkware-libs/cairo/blob/main/corelib/src/test/secp256k1_test.cairo
pub fn get_message_and_signature() -> (u256, Array<EthAddress>, Array<EthSignature>) {
    let msg_hash = 0xFBFF8940BE2153CE000C0E1933BF32E179C60F53C45F56B4AC84B2E90F1F6214;
    let validators_array: Array<EthAddress> = array![
        0x2d691f13afb546993024fde7c7249d6b325d0f6c.try_into().unwrap(),
        0xd4451a5f80bb852f26c328d776be02aae136e5e6.try_into().unwrap(),
        0x6065e100fc4c2c27e71081dfb7c455fcc71da0cb.try_into().unwrap(),
        0xa4a47265a6bc86dd47e727bd1401ef6bcf8762c1.try_into().unwrap(),
        0x6059baffb40bef2052edd4d1280dd7c6e30a71e3.try_into().unwrap()
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

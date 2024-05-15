use core::result::ResultTrait;
use hyperlane_starknet::contracts::mocks::message_recipient::message_recipient;
use hyperlane_starknet::interfaces::{
    IMailboxDispatcher, IMailboxDispatcherTrait, IMessageRecipientDispatcher,
    IMessageRecipientDispatcherTrait, IInterchainSecurityModule,
    IInterchainSecurityModuleDispatcher, IInterchainSecurityModuleDispatcherTrait,
    IMultisigIsmDispatcher, IMultisigIsmDispatcherTrait, IValidatorAnnounceDispatcher,
    IValidatorAnnounceDispatcherTrait, IMailboxClientDispatcher, IMailboxClientDispatcherTrait
};
use snforge_std::{
    declare, ContractClassTrait, CheatTarget, EventSpy, EventAssertions, spy_events, SpyOn
};
use starknet::secp256_trait::Signature;

use starknet::{ContractAddress, contract_address_const, EthAddress};

pub const LOCAL_DOMAIN: u32 = 534352;
pub const DESTINATION_DOMAIN: u32 = 9841001;

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

pub fn VALIDATOR_ADDRESS() -> EthAddress {
    'VALIDATOR_ADDRESS'.try_into().unwrap()
}

pub fn VALIDATOR_PUBLIC_KEY() -> u256 {
    'VALIDATOR_PUBLIC_KEY'
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

pub fn setup_messageid_multisig_ism() -> IInterchainSecurityModuleDispatcher {
    let messageid_multisig_class = declare("messageid_multisig_ism").unwrap();

    let (messageid_multisig_addr, _) = messageid_multisig_class.deploy(@array![]).unwrap();
    IInterchainSecurityModuleDispatcher { contract_address: messageid_multisig_addr }
}

pub fn setup_multisig_ism() -> IMultisigIsmDispatcher {
    let multisig_ism_class = declare("multisig_ism").unwrap();
    let (multisig_ism_addr, _) = multisig_ism_class.deploy(@array![OWNER().into()]).unwrap();
    IMultisigIsmDispatcher { contract_address: multisig_ism_addr }
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


// Configuration from the main cairo repo: https://github.com/starkware-libs/cairo/blob/main/corelib/src/test/secp256k1_test.cairo
pub fn get_message_and_signature(y_parity: bool) -> (u256, Array<EthAddress>, Array<Signature>) {
    let msg_hash = 0xfbff8940be2153ce000c0e1933bf32e179c60f53c45f56b4ac84b2e90f1f6214;
    let validators_array: Array<EthAddress> = array![
        0x2cb1a91F2F23D6eC7FD22d2f7996f55B71EB32dc.try_into().unwrap(),
        0x0fb1A81BcefDEc06154279219F227938D00B1c12.try_into().unwrap(),
        0xF650b555CFDEfF61d225058e26326266E69660c2.try_into().unwrap(),
        0x03aC66d13dc1B5b10fc363fC32f324ca947CDac1.try_into().unwrap(),
        0x5711B186cdCAFD9E7aa1f78c0A0c30d3C7A2Af77.try_into().unwrap()
    ];
    let signatures = array![
        Signature {
            r: 0xb994fec0137776002d05dcf847bbba338285f1210c9ca7829109578ac876519f,
            s: 0x0a42bb91f22ef042ca82fdcf8c8a5846e0debbce509dc2a0ce28a988dcbe4a16,
            y_parity
        },
        Signature {
            r: 0xf81a5dd3f871ad2d27a3b538e73663d723f8263fb3d289514346d43d000175f5,
            s: 0x083df770623e9ae52a7bb154473961e24664bb003bdfdba6100fb5e540875ce1,
            y_parity
        },
        Signature {
            r: 0x76b194f951f94492ca582dab63dc413b9ac1ca9992c22bc2186439e9ab8fdd3c,
            s: 0x62a6a6f402edaa53e9bdc715070a61edb0d98d4e14e182f60bdd4ae932b40b29,
            y_parity
        },
        Signature {
            r: 0x35932eefd85897d868aaacd4ba7aee81a2384e42ba062133f6d37fdfebf94ad4,
            s: 0x78cce49db96ee27c3f461800388ac95101476605baa64a194b7dd4d56d2d4a4d,
            y_parity
        },
        Signature {
            r: 0x6b38d4353d69396e91c57542254348d16459d448ab887574e9476a6ff76d49a1,
            s: 0x3527627295bde423d7d799afef22affac4f00c70a5b651ad14c8879aeb9b6e03,
            y_parity
        }
    ];

    (msg_hash, validators_array, signatures)
}

use core::result::ResultTrait;
use hyperlane_starknet::contracts::mocks::message_recipient::message_recipient;
use hyperlane_starknet::interfaces::{
    IMailboxDispatcher, IMailboxDispatcherTrait, IMessageRecipientDispatcher,
    IMessageRecipientDispatcherTrait
};
use snforge_std::{
    declare, ContractClassTrait, CheatTarget, EventSpy, EventAssertions, spy_events, SpyOn
};

use starknet::{ContractAddress, contract_address_const};

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

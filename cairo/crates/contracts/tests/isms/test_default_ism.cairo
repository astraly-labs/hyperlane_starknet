use alexandria_bytes::{Bytes, BytesTrait};
use contracts::interfaces::{
    IInterchainSecurityModuleDispatcher, IInterchainSecurityModuleDispatcherTrait,
    IMailboxDispatcher, IMailboxDispatcherTrait, IPausableIsmDispatcher,
    IPausableIsmDispatcherTrait, ModuleType,
};
use contracts::libs::message::{HYPERLANE_VERSION, Message, MessageTrait};
use contracts::utils::utils::U256TryIntoContractAddress;
use openzeppelin::access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};
use snforge_std::{CheatSpan, cheat_caller_address};
use super::super::setup::{
    DESTINATION_DOMAIN, DESTINATION_MAILBOX, LOCAL_DOMAIN, OWNER, mock_setup, setup_noop_ism,
    setup_pausable_ism, setup_trusted_relayer_ism,
};


#[test]
fn test_verify_noop_ism() {
    let noop_ism = setup_noop_ism();
    let message = MessageTrait::default();
    let metadata = BytesTrait::new_empty();
    assert_eq!(noop_ism.verify(@metadata, @message), true);
    assert_eq!(noop_ism.module_type(), ModuleType::NULL(()));
}


#[test]
fn test_verify_trusted_relayer_ism() {
    let trusted_ism = setup_trusted_relayer_ism();
    let ownable = IOwnableDispatcher { contract_address: DESTINATION_MAILBOX() };
    cheat_caller_address(
        ownable.contract_address, OWNER().try_into().unwrap(), CheatSpan::TargetCalls(2),
    );
    let mailbox = IMailboxDispatcher { contract_address: DESTINATION_MAILBOX() };
    mailbox.set_default_ism(trusted_ism.contract_address);
    let (mock_recipient, _) = mock_setup(trusted_ism.contract_address);
    // mailbox.set_local_domain(DESTINATION_DOMAIN);
    let array = array![
        0x01020304050607080910111213141516,
        0x01020304050607080910111213141516,
        0x01020304050607080910000000000000,
    ];
    let recipient: felt252 = mock_recipient.contract_address.into();
    let message_body = BytesTrait::new(42, array);
    let message = Message {
        version: HYPERLANE_VERSION,
        nonce: 0,
        origin: LOCAL_DOMAIN,
        sender: OWNER(),
        destination: DESTINATION_DOMAIN,
        recipient: recipient.into(),
        body: message_body.clone(),
    };
    let metadata = message_body;
    mailbox.process(@metadata, message.clone());
    assert_eq!(trusted_ism.verify(@metadata, @message), true);
    assert_eq!(trusted_ism.module_type(), ModuleType::NULL(()));
}


#[test]
fn test_pause_unpause_pausable_ism() {
    let (_, pausable_ism) = setup_pausable_ism();
    let ownable = IOwnableDispatcher { contract_address: pausable_ism.contract_address };
    cheat_caller_address(
        ownable.contract_address, OWNER().try_into().unwrap(), CheatSpan::TargetCalls(2),
    );
    pausable_ism.pause();
    pausable_ism.unpause();
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_pause_pausable_ism_fails_if_not_owner() {
    let (_, pausable_ism) = setup_pausable_ism();
    pausable_ism.pause();
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_unpause_pausable_ism_fails_if_not_owner() {
    let (_, pausable_ism) = setup_pausable_ism();
    pausable_ism.unpause();
}

#[test]
fn test_verify_pausable_ism() {
    let (pausable_ism, _) = setup_pausable_ism();
    let message = MessageTrait::default();
    let metadata = BytesTrait::new_empty();
    assert_eq!(pausable_ism.verify(@metadata, @message), true);
    assert_eq!(pausable_ism.module_type(), ModuleType::NULL(()));
}

#[test]
#[should_panic(expected: ('Pausable: paused',))]
fn test_veriy_pausable_ism_fails_if_paused() {
    let (ism, pausable) = setup_pausable_ism();
    let message = MessageTrait::default();
    let metadata = BytesTrait::new_empty();
    let ownable = IOwnableDispatcher { contract_address: pausable.contract_address };
    cheat_caller_address(
        ownable.contract_address, OWNER().try_into().unwrap(), CheatSpan::TargetCalls(1),
    );
    pausable.pause();
    ism.verify(@metadata, @message);
}

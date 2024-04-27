use alexandria_bytes::{Bytes, BytesTrait};
use hyperlane_starknet::contracts::libs::message::{Message, MessageTrait};
use hyperlane_starknet::contracts::mailbox::mailbox;
use hyperlane_starknet::interfaces::IMessageRecipientDispatcherTrait;
use hyperlane_starknet::interfaces::{
    IMailbox, IMailboxDispatcher, IMailboxDispatcherTrait, HYPERLANE_VERSION
};
use hyperlane_starknet::tests::setup::{
    setup, mock_setup, OWNER, LOCAL_DOMAIN, NEW_OWNER, DEFAULT_ISM, DEFAULT_HOOK, REQUIRED_HOOK,
    NEW_DEFAULT_ISM, NEW_DEFAULT_HOOK, NEW_REQUIRED_HOOK, DESTINATION_DOMAIN, RECIPIENT_ADDRESS
};
use openzeppelin::access::ownable::OwnableComponent;
use openzeppelin::access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};
use snforge_std::cheatcodes::events::EventAssertions;
use snforge_std::{start_prank, CheatTarget, stop_prank};

#[test]
fn test_local_domain() {
    let (mailbox, _) = setup();
    assert(mailbox.get_local_domain() == LOCAL_DOMAIN, 'Wrong local domain');
}

#[test]
fn test_owner() {
    let (mailbox, _) = setup();
    let ownable = IOwnableDispatcher { contract_address: mailbox.contract_address };
    assert(ownable.owner() == OWNER(), 'Wrong contract owner');
}

#[test]
fn test_transfer_ownership() {
    let (mailbox, mut spy) = setup();
    let ownable = IOwnableDispatcher { contract_address: mailbox.contract_address };
    start_prank(CheatTarget::One(ownable.contract_address), OWNER());
    ownable.transfer_ownership(NEW_OWNER());
    stop_prank(CheatTarget::One(ownable.contract_address));
    assert(ownable.owner() == NEW_OWNER(), 'Failed transfer ownership');

    let expected_event = OwnableComponent::OwnershipTransferred {
        previous_owner: OWNER(), new_owner: NEW_OWNER()
    };
    spy
        .assert_emitted(
            @array![
                (
                    ownable.contract_address,
                    OwnableComponent::Event::OwnershipTransferred(expected_event)
                )
            ]
        );
}

#[test]
fn test_initializer() {
    let (mailbox, _) = setup();
    let ownable = IOwnableDispatcher { contract_address: mailbox.contract_address };
    start_prank(CheatTarget::One(ownable.contract_address), OWNER());
    mailbox.initializer(DEFAULT_ISM(), DEFAULT_HOOK(), REQUIRED_HOOK());
    assert(mailbox.get_default_hook() == DEFAULT_HOOK(), 'Failed to set default hook');
    assert(mailbox.get_required_hook() == REQUIRED_HOOK(), 'Failed to set required hook');
    assert(mailbox.get_default_ism() == DEFAULT_ISM(), 'Failed to set default ism');
}

#[test]
fn test_set_default_hook() {
    let (mailbox, mut spy) = setup();
    let ownable = IOwnableDispatcher { contract_address: mailbox.contract_address };
    start_prank(CheatTarget::One(ownable.contract_address), OWNER());
    mailbox.set_default_hook(NEW_DEFAULT_HOOK());
    assert(mailbox.get_default_hook() == NEW_DEFAULT_HOOK(), 'Failed to set default hook');
    let expected_event = mailbox::Event::DefaultHookSet(
        mailbox::DefaultHookSet { hook: NEW_DEFAULT_HOOK() }
    );
    spy.assert_emitted(@array![(mailbox.contract_address, expected_event)]);
}

#[test]
fn test_set_required_hook() {
    let (mailbox, mut spy) = setup();
    let ownable = IOwnableDispatcher { contract_address: mailbox.contract_address };
    start_prank(CheatTarget::One(ownable.contract_address), OWNER());
    mailbox.set_required_hook(NEW_REQUIRED_HOOK());
    assert(mailbox.get_required_hook() == NEW_REQUIRED_HOOK(), 'Failed to set required hook');
    let expected_event = mailbox::Event::RequiredHookSet(
        mailbox::RequiredHookSet { hook: NEW_REQUIRED_HOOK() }
    );
    spy.assert_emitted(@array![(mailbox.contract_address, expected_event)]);
}

#[test]
fn test_set_default_ism() {
    let (mailbox, mut spy) = setup();
    let ownable = IOwnableDispatcher { contract_address: mailbox.contract_address };
    start_prank(CheatTarget::One(ownable.contract_address), OWNER());
    mailbox.set_default_ism(NEW_DEFAULT_ISM());
    assert(mailbox.get_default_ism() == NEW_DEFAULT_ISM(), 'Failed to set default ism');
    let expected_event = mailbox::Event::DefaultIsmSet(
        mailbox::DefaultIsmSet { module: NEW_DEFAULT_ISM() }
    );
    spy.assert_emitted(@array![(mailbox.contract_address, expected_event)]);
}
#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_set_default_hook_fails_if_not_owner() {
    let (mailbox, _) = setup();
    let ownable = IOwnableDispatcher { contract_address: mailbox.contract_address };
    start_prank(CheatTarget::One(ownable.contract_address), NEW_OWNER());
    mailbox.set_default_hook(NEW_DEFAULT_HOOK());
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_set_required_hook_fails_if_not_owner() {
    let (mailbox, _) = setup();
    let ownable = IOwnableDispatcher { contract_address: mailbox.contract_address };
    start_prank(CheatTarget::One(ownable.contract_address), NEW_OWNER());
    mailbox.set_required_hook(NEW_REQUIRED_HOOK());
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_set_default_ism_fails_if_not_owner() {
    let (mailbox, _) = setup();
    let ownable = IOwnableDispatcher { contract_address: mailbox.contract_address };
    start_prank(CheatTarget::One(ownable.contract_address), NEW_OWNER());
    mailbox.set_default_ism(NEW_DEFAULT_ISM());
}

#[test]
fn test_dispatch() {
    let (mailbox, mut spy) = setup();
    let ownable = IOwnableDispatcher { contract_address: mailbox.contract_address };
    start_prank(CheatTarget::One(ownable.contract_address), OWNER());
    let array = array![
        0x01020304050607080910111213141516,
        0x01020304050607080910111213141516,
        0x01020304050607080910000000000000
    ];

    let message_body = BytesTrait::new(42, array);
    let message = Message {
        version: HYPERLANE_VERSION,
        nonce: 0,
        origin: LOCAL_DOMAIN,
        sender: OWNER(),
        destination: DESTINATION_DOMAIN,
        recipient: RECIPIENT_ADDRESS(),
        body: message_body.clone()
    };
    let message_id = MessageTrait::format_message(message.clone());
    mailbox
        .dispatch(
            DESTINATION_DOMAIN, RECIPIENT_ADDRESS(), message_body, Option::None, Option::None
        );
    let expected_event = mailbox::Event::Dispatch(
        mailbox::Dispatch {
            sender: OWNER(),
            destination_domain: DESTINATION_DOMAIN,
            recipient_address: RECIPIENT_ADDRESS(),
            message: message_id
        }
    );
    let expected_event_id = mailbox::Event::DispatchId(mailbox::DispatchId { id: message_id });

    spy
        .assert_emitted(
            @array![
                (mailbox.contract_address, expected_event),
                (mailbox.contract_address, expected_event_id)
            ]
        );

    assert(mailbox.get_latest_dispatched_id() == message_id, 'Failed to fetch latest id');
}


#[test]
fn test_process() {
    let (mailbox, mut spy) = setup();
    let mock_recipient = mock_setup();
    let ownable = IOwnableDispatcher { contract_address: mailbox.contract_address };
    start_prank(CheatTarget::One(ownable.contract_address), OWNER());
    mailbox.set_local_domain(DESTINATION_DOMAIN);
    let array = array![
        0x01020304050607080910111213141516,
        0x01020304050607080910111213141516,
        0x01020304050607080910000000000000
    ];

    let message_body = BytesTrait::new(42, array);
    let message = Message {
        version: HYPERLANE_VERSION,
        nonce: 0,
        origin: LOCAL_DOMAIN,
        sender: OWNER(),
        destination: DESTINATION_DOMAIN,
        recipient: mock_recipient.contract_address,
        body: message_body.clone()
    };
    let message_id = MessageTrait::format_message(message.clone());
    let metadata = message_body;
    mailbox.process(metadata.clone(), message);
    let expected_event = mailbox::Event::Process(
        mailbox::Process {
            origin: LOCAL_DOMAIN, sender: OWNER(), recipient: mock_recipient.contract_address,
        }
    );
    let expected_event_id = mailbox::Event::ProcessId(mailbox::ProcessId { id: message_id });

    spy
        .assert_emitted(
            @array![
                (mailbox.contract_address, expected_event),
                (mailbox.contract_address, expected_event_id)
            ]
        );
    let block_number = starknet::get_block_number();
    assert(mailbox.delivered(message_id), 'Failed to delivered(id)');
    assert(mailbox.processor(message_id) == OWNER(), 'Wrong processor');
    assert(mailbox.processed_at(message_id) == block_number, 'Wrong processed block number');
    assert(mock_recipient.get_origin() == LOCAL_DOMAIN, 'Failed to retrieve origin');
    assert(mock_recipient.get_sender() == OWNER(), 'Failed to retrieve sender');
    assert(mock_recipient.get_message() == metadata, 'Failed to retrieve metadata');

}

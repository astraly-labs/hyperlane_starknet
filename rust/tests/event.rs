use crate::strk::mailbox::Dispatch as DispatchEvent;
use starknet::core::{types::Event, utils::get_selector_from_name};

pub fn parse_dispatch_from_res(events: &[Event]) -> DispatchEvent {
    let key = get_selector_from_name("Dispatch").unwrap(); // safe to unwrap
    let found = events.iter().find(|v| v.keys.contains(&key)).unwrap();

    DispatchEvent {
        sender: cainome::cairo_serde::ContractAddress(found.data[0]),
        destination_domain: found.data[1].try_into().unwrap(),
        recipient_address: cainome::cairo_serde::ContractAddress(found.data[2]),
        message: (found.data[3], found.data[4]).try_into().unwrap(),
    }
}

#[starknet::contract]
mod mailboxclient {
    use openzeppelin::access::ownable::ownable::OwnableComponent::InternalTrait;
use hyperlane_starknet::contracts::client::mailboxclient_component::{MailboxclientComponent, MailboxclientComponent::MailboxClientInternalImpl};
    use openzeppelin::access::ownable::{OwnableComponent, };
    use starknet::ContractAddress;
    component!(path: MailboxclientComponent, storage: mailboxclient, event: MailboxclientEvent);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        mailboxclient: MailboxclientComponent::Storage,
    }

    #[constructor]
    fn constructor(ref self: ContractState, _mailbox: ContractAddress, _owner: ContractAddress, ) {
        self.mailboxclient.initialize(_mailbox);
        self.ownable.initializer(_owner);
    }


    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        MailboxclientEvent: MailboxclientComponent::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[abi(embed_v0)]
    impl MailboxclientImpl = MailboxclientComponent::MailboxClientImpl<ContractState>;
    

}

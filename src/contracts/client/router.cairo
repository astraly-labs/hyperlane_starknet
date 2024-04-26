#[starknet::contract]
mod router {

    use starknet::{ContractAddress, get_caller_address, ClassHash, contract_address_const};
    use alexandria_storage::list::{List, ListTrait};
    use hyperlane_starknet::contracts::libs::message::Message;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::upgrades::{interface::IUpgradeable, upgradeable::UpgradeableComponent};
    use hyperlane_starknet::interfaces::IRouter;
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    type Domain = u32;
    #[storage]
    struct Storage {
        routers: LegacyMap<Domain,ContractAddress>,
        mailbox: ContractAddress,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }


    mod Errors {
        pub const LENGTH_MISMATCH: felt252 = 'Domains and Router len mismatch';
        pub const CALLER_IS_NOT_MAILBOX: felt252 = 'Caller is not mailbox';
        pub const NO_ROUTER_FOR_DOMAIN: felt252 = 'No router for domain';
        pub const ENROLLED_ROUTER_AND_SENDER_MISMATCH: felt252 = 'Enrolled router/sender mismatch';

    }

    #[constructor]
    fn constructor(ref self: ContractState, _mailbox: ContractAddress) {
        self.mailbox.write(_mailbox);
    }
    
    #[abi(embed_v0)]
    impl Upgradeable of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable._upgrade(new_class_hash);
        }
    }

    #[abi(embed_v0)]
    impl IRouterImpl of IRouter<ContractState> {


        fn routers(self: @ContractState, _domain: u32) -> ContractAddress {
            self.routers.read(_domain)
        }

        fn unenroll_remote_router(ref self: ContractState, _domain: u32){
            self.ownable.assert_only_owner();
            _unenroll_remote_router(ref self, _domain);

        }

        fn enroll_remote_router(ref self: ContractState, _domain: u32, _router: ContractAddress) {
            self.ownable.assert_only_owner();
            _enroll_remote_router(ref self , _domain, _router);
        }

        fn enroll_remote_routers(ref self: ContractState, _domains: Span<u32>, _routers: Span<ContractAddress>){
            self.ownable.assert_only_owner();
            assert(_domains.len()==_routers.len(), Errors::LENGTH_MISMATCH);
            let length = _domains.len();
            let mut cur_idx = 0;
            loop {
                if (cur_idx == length){
                    break();
                }
                _enroll_remote_router(ref self, *_domains.at(cur_idx), *_routers.at(cur_idx));
                cur_idx +=1 ;
            }
        }

         fn unenroll_remote_routers(ref self: ContractState, _domains: Span<u32>){
            self.ownable.assert_only_owner();
            let length = _domains.len();
            let mut cur_idx = 0;
            loop {
                if (cur_idx == length){
                    break();
                }
                _unenroll_remote_router(ref self, *_domains.at(cur_idx));
                cur_idx +=1 ;
            }
        } 

        fn handle(self: @ContractState, _origin: u32, _sender: ContractAddress, _message: Message) {
            let caller = get_caller_address(); 
            assert(caller ==self.mailbox.read(),Errors::CALLER_IS_NOT_MAILBOX);
            let router = _must_have_remote_router(self,_origin);
            assert(router == _sender , Errors::ENROLLED_ROUTER_AND_SENDER_MISMATCH);
            _handle(_origin, _sender, _message);
        }
    
    }

    fn _unenroll_remote_router(ref self: ContractState, _domain: u32) {
        self.routers.write(_domain, contract_address_const::<0>());
    }

    fn _enroll_remote_router(ref self: ContractState, _domain :u32, _address: ContractAddress){
        self.routers.write(_domain, _address);
    }

    fn _must_have_remote_router(self: @ContractState, _domain: u32) -> ContractAddress {
        let router = self.routers.read(_domain);
        assert(router!=0.try_into().unwrap(), Errors::NO_ROUTER_FOR_DOMAIN);
        router
    }
 
    fn _is_remote_Router(self: @ContractState, _domain: u32, _address: ContractAddress) -> bool {
        let router = self.routers.read(_domain);
        router == _address
    }

    fn _handle(_origin: u32, _sender: ContractAddress, _message: Message) {

    }
}
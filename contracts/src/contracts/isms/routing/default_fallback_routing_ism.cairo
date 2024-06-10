#[starknet::contract]
pub mod default_fallback_routing_ism {
    use alexandria_bytes::Bytes;
    use core::panic_with_felt252;
    use hyperlane_starknet::contracts::libs::message::{Message, MessageTrait};
    use hyperlane_starknet::interfaces::{
        IDomainRoutingIsm, IRoutingIsm, IInterchainSecurityModule, ModuleType,
        IInterchainSecurityModuleDispatcher, IInterchainSecurityModuleDispatcherTrait,
        IMailboxClientDispatcher, IMailboxClientDispatcherTrait, IMailboxDispatcher,
        IMailboxDispatcherTrait
    };

    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::upgrades::{interface::IUpgradeable, upgradeable::UpgradeableComponent};

    use starknet::{ContractAddress, contract_address_const};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    type Domain = u32;
    type Index = u32;
    #[storage]
    struct Storage {
        modules: LegacyMap<Domain, ContractAddress>,
        domains: LegacyMap<Domain, Domain>,
        mailbox_client: ContractAddress,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }

    mod Errors {
        pub const LENGTH_MISMATCH: felt252 = 'Length mismatch';
        pub const MODULE_CANNOT_BE_ZERO: felt252 = 'Module cannot be zero';
        pub const DOMAIN_NOT_FOUND: felt252 = 'Domain not found';
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, _owner: ContractAddress, _mailbox_client: ContractAddress
    ) {
        self.ownable.initializer(_owner);
        self.mailbox_client.write(_mailbox_client);
    }

    #[abi(embed_v0)]
    impl IDomainRoutingIsmImpl of IDomainRoutingIsm<ContractState> {
        fn initialize(
            ref self: ContractState, _domains: Span<u32>, _modules: Span<ContractAddress>
        ) {
            self.ownable.assert_only_owner();
            assert(_domains.len() == _modules.len(), Errors::LENGTH_MISMATCH);
            let mut cur_idx = 0;
            loop {
                if (cur_idx == _domains.len()) {
                    break ();
                }
                assert(
                    *_modules.at(cur_idx) != contract_address_const::<0>(),
                    Errors::MODULE_CANNOT_BE_ZERO
                );
                let test: felt252 = (*_modules.at(cur_idx)).try_into().unwrap();
                _set(ref self, *_domains.at(cur_idx), *_modules.at(cur_idx));
                cur_idx += 1;
            }
        }

        fn set(ref self: ContractState, _domain: u32, _module: ContractAddress) {
            self.ownable.assert_only_owner();
            assert(_module != contract_address_const::<0>(), Errors::MODULE_CANNOT_BE_ZERO);
            _set(ref self, _domain, _module);
        }

        fn remove(ref self: ContractState, _domain: u32) {
            self.ownable.assert_only_owner();
            _remove(ref self, _domain);
        }

        fn domains(self: @ContractState) -> Span<u32> {
            let mut current_domain = self.domains.read(0);
            let mut domains = array![];
            loop {
                let next_domain = self.domains.read(current_domain);
                if next_domain == 0 {
                    domains.append(current_domain);
                    break ();
                }
                domains.append(current_domain);
                current_domain = next_domain;
            };
            domains.span()
        }

        fn module(self: @ContractState, _origin: u32) -> ContractAddress {
            let module = self.modules.read(_origin);
            if (module != contract_address_const::<0>()) {
                module
            } else {
                let mailbox_client_dispatcher = IMailboxClientDispatcher {
                    contract_address: self.mailbox_client.read()
                };
                let mailbox_address = mailbox_client_dispatcher.get_mailbox();
                IMailboxDispatcher { contract_address: mailbox_address }.get_default_ism()
            }
        }
    }

    #[abi(embed_v0)]
    impl IRoutingIsmImpl of IRoutingIsm<ContractState> {
        fn route(self: @ContractState, _message: Message) -> ContractAddress {
            self.modules.read(_message.origin)
        }
    }

    #[abi(embed_v0)]
    impl IInterchainSecurityModuleImpl of IInterchainSecurityModule<ContractState> {
        fn module_type(self: @ContractState) -> ModuleType {
            ModuleType::ROUTING(starknet::get_contract_address())
        }

        fn verify(self: @ContractState, _metadata: Bytes, _message: Message) -> bool {
            let ism_address = self.route(_message.clone());
            let ism_dispatcher = IInterchainSecurityModuleDispatcher {
                contract_address: ism_address
            };
            ism_dispatcher.verify(_metadata, _message)
        }
    }

    fn find_last_domain(self: @ContractState) -> u32 {
        let mut current_domain = self.domains.read(0);
        loop {
            let next_domain = self.domains.read(current_domain);
            if next_domain == 0 {
                break current_domain;
            }
            current_domain = next_domain;
        }
    }

    fn find_domain_index(self: @ContractState, _domain: u32) -> Option<u32> {
        let mut current_domain = 0;
        loop {
            let next_domain = self.domains.read(current_domain);
            if next_domain == _domain {
                break Option::Some(current_domain);
            } else if next_domain == 0 {
                break Option::None(());
            }
            current_domain = next_domain;
        }
    }

    fn _remove(ref self: ContractState, _domain: u32) {
        let domain_index = match find_domain_index(@self, _domain) {
            Option::Some(index) => index,
            Option::None => {
                panic_with_felt252(Errors::DOMAIN_NOT_FOUND);
                0
            }
        };
        let next_domain = self.domains.read(_domain);
        self.domains.write(domain_index, next_domain);
    }

    fn _set(ref self: ContractState, _domain: u32, _module: ContractAddress) {
        match find_domain_index(@self, _domain) {
            Option::Some(_) => {},
            Option::None => {
                let latest_domain = find_last_domain(@self);
                self.domains.write(latest_domain, _domain);
            }
        }
        self.modules.write(_domain, _module);
    }
}

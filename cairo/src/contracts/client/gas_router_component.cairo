use GasRouterComponent::GasRouterConfig;

#[starknet::interface]
pub trait IGasRouter<TState> {
    fn set_destination_gas(
        ref self: TState,
        gas_configs: Option<Array<GasRouterConfig>>,
        domain: Option<u32>,
        gas: Option<u256>
    );
    fn quote_gas_payment(self: @TState, destination_domain: u32) -> u256;
}

#[starknet::component]
pub mod GasRouterComponent {
    use alexandria_bytes::{Bytes, BytesTrait};
    use hyperlane_starknet::contracts::client::mailboxclient_component::{
        MailboxclientComponent, MailboxclientComponent::MailboxClientInternalImpl
    };
    use hyperlane_starknet::contracts::client::router_component::{
        RouterComponent, RouterComponent::RouterComponentInternalImpl, IRouter,
    };
    use hyperlane_starknet::contracts::hooks::libs::standard_hook_metadata::standard_hook_metadata::StandardHookMetadata;
    use hyperlane_starknet::interfaces::{IMailboxClient};
    use openzeppelin::access::ownable::{
        OwnableComponent, OwnableComponent::InternalImpl as OwnableInternalImpl
    };
    use starknet::ContractAddress;

    #[derive(Copy, Drop, Serde)]
    pub struct GasRouterConfig {
        pub domain: u32,
        pub gas: u256,
    }

    #[storage]
    struct Storage {
        destination_gas: LegacyMap<u32, u256>,
    }

    #[embeddable_as(GasRouterImpl)]
    impl GasRouter<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl MailBoxClient: MailboxclientComponent::HasComponent<TContractState>,
        impl Router: RouterComponent::HasComponent<TContractState>,
        impl Owner: OwnableComponent::HasComponent<TContractState>,
    > of super::IGasRouter<ComponentState<TContractState>> {
        fn set_destination_gas(
            ref self: ComponentState<TContractState>,
            gas_configs: Option<Array<GasRouterConfig>>,
            domain: Option<u32>,
            gas: Option<u256>
        ) {
            let owner_comp = get_dep_component!(@self, Owner);
            owner_comp.assert_only_owner();

            match gas_configs {
                Option::Some(gas_configs) => {
                    let configs_len = gas_configs.len();
                    let mut i = 0;

                    while i < configs_len {
                        let config = *gas_configs.at(i);
                        self._set_destination_gas(config.domain, config.gas);
                        i += 1;
                    };
                },
                Option::None => {
                    match (domain, gas) {
                        (
                            Option::Some(domain), Option::Some(gas)
                        ) => { self._set_destination_gas(domain, gas); },
                        _ => { panic!("Set destination gas: Invalid arguments"); }
                    }
                }
            }
        }

        fn quote_gas_payment(
            self: @ComponentState<TContractState>, destination_domain: u32
        ) -> u256 {
            let mailbox_comp = get_dep_component!(self, MailBoxClient);
            let hook = mailbox_comp.get_hook();
            self._Gas_router_quote_dispatch(destination_domain, BytesTrait::new_empty(), hook)
        }
    }

    #[generate_trait]
    pub impl GasRouterInternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl MailBoxClient: MailboxclientComponent::HasComponent<TContractState>,
        impl Router: RouterComponent::HasComponent<TContractState>,
        +Drop<TContractState>
    > of InternalTrait<TContractState> {
        fn _Gas_router_hook_metadata(
            self: @ComponentState<TContractState>, destination: u32
        ) -> Bytes {
            StandardHookMetadata::override_gas_limits(self.destination_gas.read(destination))
        }

        fn _set_destination_gas(ref self: ComponentState<TContractState>, domain: u32, gas: u256) {
            self.destination_gas.write(domain, gas);
        }

        fn _Gas_router_dispatch(
            ref self: ComponentState<TContractState>,
            destination: u32,
            value: u256,
            message_body: Bytes,
            hook: ContractAddress
        ) -> u256 {
            let mut router_comp = get_dep_component_mut!(ref self, Router);
            router_comp
                ._Router_dispatch(
                    destination,
                    value,
                    message_body,
                    self._Gas_router_hook_metadata(destination),
                    hook
                )
        }

        fn _Gas_router_quote_dispatch(
            self: @ComponentState<TContractState>,
            destination: u32,
            message_body: Bytes,
            hook: ContractAddress
        ) -> u256 {
            let mut router_comp = get_dep_component!(self, Router);
            router_comp
                ._Router_quote_dispatch(
                    destination, message_body, self._Gas_router_hook_metadata(destination), hook
                )
        }
    }
}

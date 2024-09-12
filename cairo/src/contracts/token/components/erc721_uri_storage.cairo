#[starknet::interface]
pub trait IERC721URIStorage<TContractState> {
    fn token_uri(self: @TContractState, token_id: u256) -> ByteArray;
}

#[starknet::component]
pub mod ERC721URIStorageComponent {
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::{
        ERC721Component, ERC721Component::InternalTrait as ERC721InternalTrait,
        ERC721Component::ERC721HooksTrait, ERC721Component::ERC721MetadataImpl
    };

    #[storage]
    struct Storage {
        token_uris: LegacyMap<u256, ByteArray>
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        MetadataUpdate: MetadataUpdate,
    }

    #[derive(Drop, starknet::Event)]
    struct MetadataUpdate {
        token_id: u256,
    }

    #[embeddable_as(ERC721URIStorageImpl)]
    impl ERC721URIStorage<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +ERC721HooksTrait<TContractState>,
        impl ERC721: ERC721Component::HasComponent<TContractState>,
    > of super::IERC721URIStorage<ComponentState<TContractState>> {
        fn token_uri(self: @ComponentState<TContractState>, token_id: u256) -> ByteArray {
            let erc721_component = get_dep_component!(self, ERC721);
            erc721_component._require_owned(token_id);

            let token_uri = self.token_uris.read(token_id);
            let mut base = erc721_component._base_uri();

            if base.len() == 0 {
                return token_uri;
            }

            if token_uri.len() > 0 {
                base.append(@token_uri);
                return base;
            }

            erc721_component.token_uri(token_id)
        }
    }

    #[generate_trait]
    impl ERC721URIStorageInternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +ERC721HooksTrait<TContractState>,
        +ERC721Component::HasComponent<TContractState>,
    > of InternalTrait<TContractState> {
        fn _set_token_uri(
            ref self: ComponentState<TContractState>, token_id: u256, token_uri: ByteArray
        ) {
            self.token_uris.write(token_id, token_uri);
            self.emit(MetadataUpdate { token_id });
        }
    }
}

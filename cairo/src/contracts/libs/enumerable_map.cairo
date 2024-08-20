use core::hash::{HashStateTrait};
use core::num::traits::Zero;
use core::pedersen::PedersenTrait;
use core::poseidon::poseidon_hash_span;
use starknet::storage_access::{
    StorageBaseAddress, storage_address_from_base, storage_base_address_from_felt252
};
use starknet::{Store, SyscallResultTrait, SyscallResult};

const NOT_IMPLEMENTED: felt252 = 'Not implemented';
const INDEX_OUT_OF_BOUNDS: felt252 = 'Index out of bounds!';

// Enumerable map
// struct EnumerableMap {
//   values: Map<K,V>
//   keys: List<K>  
//   positions: Map<K,u32>  
// }
#[derive(Copy, Drop)]
pub struct EnumerableMap<K, V> {
    address_domain: u32,
    base: StorageBaseAddress
}

pub impl EnumerableMapStore<
    K, V, +Store<K>, +Drop<K>, +Store<V>, +Drop<V>
> of Store<EnumerableMap<K, V>> {
    #[inline(always)]
    fn read(address_domain: u32, base: StorageBaseAddress) -> SyscallResult<EnumerableMap<K, V>> {
        SyscallResult::Ok(EnumerableMap::<K, V> { address_domain, base })
    }

    #[inline(always)]
    fn write(
        address_domain: u32, base: StorageBaseAddress, value: EnumerableMap<K, V>
    ) -> SyscallResult<()> {
        SyscallResult::Err(array![NOT_IMPLEMENTED])
    }

    #[inline(always)]
    fn read_at_offset(
        address_domain: u32, base: StorageBaseAddress, offset: u8
    ) -> SyscallResult<EnumerableMap<K, V>> {
        SyscallResult::Err(array![NOT_IMPLEMENTED])
    }
    #[inline(always)]
    fn write_at_offset(
        address_domain: u32, base: StorageBaseAddress, offset: u8, value: EnumerableMap<K, V>
    ) -> SyscallResult<()> {
        SyscallResult::Err(array![NOT_IMPLEMENTED])
    }
    #[inline(always)]
    fn size() -> u8 {
        // 0 was selected because the read method doesn't actually read from storage
        0_u8
    }
}

pub trait EnumerableMapTrait<K, V> {
    fn get(self: @EnumerableMap<K, V>, key: @K) -> V;
    fn set(ref self: EnumerableMap<K, V>, key: @K, val: @V) -> ();
    fn len(self: @EnumerableMap<K, V>) -> u32;
    fn contains(self: @EnumerableMap<K, V>, key: @K) -> bool;
    fn remove(ref self: EnumerableMap<K, V>, key: @K) -> bool;
    fn at(self: @EnumerableMap<K, V>, index: u32) -> (K, V);
    fn keys(self: @EnumerableMap<K, V>) -> Array<K>;
}

pub impl EnumerableMapImpl<
    K,
    V,
    +Drop<K>,
    +Drop<V>,
    +Store<K>,
    +Store<V>,
    +Copy<K>,
    +Copy<V>,
    +Zero<K>,
    +Zero<V>,
    +Serde<K>,
> of EnumerableMapTrait<K, V> {
    fn get(self: @EnumerableMap<K, V>, key: @K) -> V {
        EnumerableMapInternalTrait::<K, V>::values_mapping_read(self, key)
    }

    fn set(ref self: EnumerableMap<K, V>, key: @K, val: @V) {
        EnumerableMapInternalTrait::<K, V>::values_mapping_write(ref self, key, val);
        // appends 'key' to array and updates 'position' mapping
        EnumerableMapInternalTrait::<K, V>::array_append(ref self, key);
    }

    fn len(self: @EnumerableMap<K, V>) -> u32 {
        Store::<u32>::read(*self.address_domain, *self.base).unwrap_syscall()
    }

    fn contains(self: @EnumerableMap<K, V>, key: @K) -> bool {
        EnumerableMapInternalTrait::<K, V>::positions_mapping_read(self, key) != 0
    }

    fn remove(ref self: EnumerableMap<K, V>, key: @K) -> bool {
        if !self.contains(key) {
            return false;
        }
        let index = EnumerableMapInternalImpl::<K, V>::positions_mapping_read(@self, key) - 1;
        // Deletes `key` from 'values' mapping
        EnumerableMapInternalTrait::<K, V>::values_mapping_write(ref self, key, @Zero::<V>::zero());
        // Deletes `key`` from 'array' and 'positions' mapping
        EnumerableMapInternalTrait::<K, V>::array_remove(ref self, @index)
    }

    fn at(self: @EnumerableMap<K, V>, index: u32) -> (K, V) {
        assert(index < self.len(), INDEX_OUT_OF_BOUNDS);
        let key = EnumerableMapInternalTrait::<K, V>::array_read(self, @index);
        let val = EnumerableMapInternalTrait::<K, V>::values_mapping_read(self, @key);
        (key, val)
    }

    fn keys(self: @EnumerableMap<K, V>) -> Array<K> {
        let mut i = 0;
        let len = self.len();
        let mut keys = array![];
        while i < len {
            let key = EnumerableMapInternalTrait::<K, V>::array_read(self, @i);
            keys.append(key);
            i += 1;
        };
        keys
    }
}

trait EnumerableMapInternalTrait<K, V> {
    fn values_mapping_write(ref self: EnumerableMap<K, V>, key: @K, val: @V);
    fn values_mapping_read(self: @EnumerableMap<K, V>, key: @K) -> V;
    fn positions_mapping_write(ref self: EnumerableMap<K, V>, key: @K, val: @u32);
    fn positions_mapping_read(self: @EnumerableMap<K, V>, key: @K) -> u32;
    fn update_array_len(ref self: EnumerableMap<K, V>, new_len: @u32);
    fn array_append(ref self: EnumerableMap<K, V>, key: @K);
    fn array_remove(ref self: EnumerableMap<K, V>, index: @u32) -> bool;
    fn array_read(self: @EnumerableMap<K, V>, index: @u32) -> K;
    fn array_write(ref self: EnumerableMap<K, V>, index: @u32, val: K);
}

impl EnumerableMapInternalImpl<
    K,
    V,
    +Drop<K>,
    +Drop<V>,
    +Store<K>,
    +Store<V>,
    +Copy<K>,
    +Copy<V>,
    +Zero<K>,
    +Zero<V>,
    +Serde<K>,
> of EnumerableMapInternalTrait<K, V> {
    fn values_mapping_write(ref self: EnumerableMap<K, V>, key: @K, val: @V) {
        let storage_base_felt: felt252 = storage_address_from_base(self.base).into();
        let mut storage_address_val = PedersenTrait::new(storage_base_felt).update('values');
        let mut serialized_key: Array<felt252> = array![];
        key.serialize(ref serialized_key);
        let mut i = 0;
        let len = serialized_key.len();
        while i < len {
            storage_address_val = storage_address_val.update(*serialized_key.at(i));
            i += 1;
        };
        let storage_address_val_felt = storage_address_val.finalize();
        Store::<
            V
        >::write(
            self.address_domain, storage_base_address_from_felt252(storage_address_val_felt), *val
        )
            .unwrap_syscall();
    }

    fn values_mapping_read(self: @EnumerableMap<K, V>, key: @K) -> V {
        let storage_base_felt: felt252 = storage_address_from_base(*self.base).into();
        let mut storage_address_val = PedersenTrait::new(storage_base_felt).update('values');
        let mut serialized_key: Array<felt252> = array![];
        key.serialize(ref serialized_key);
        let mut i = 0;
        let len = serialized_key.len();
        while i < len {
            storage_address_val = storage_address_val.update(*serialized_key.at(i));
            i += 1;
        };
        let storage_address_val_felt = storage_address_val.finalize();
        Store::<
            V
        >::read(*self.address_domain, storage_base_address_from_felt252(storage_address_val_felt))
            .unwrap_syscall()
    }

    fn positions_mapping_write(ref self: EnumerableMap<K, V>, key: @K, val: @u32) {
        let storage_base_felt: felt252 = storage_address_from_base(self.base).into();
        let mut storage_address_val = PedersenTrait::new(storage_base_felt).update('positions');
        let mut serialized_key: Array<felt252> = array![];
        key.serialize(ref serialized_key);
        let mut i = 0;
        let len = serialized_key.len();
        while i < len {
            storage_address_val = storage_address_val.update(*serialized_key.at(i));
            i += 1;
        };
        let storage_address_val_felt = storage_address_val.finalize();
        Store::<
            u32
        >::write(
            self.address_domain, storage_base_address_from_felt252(storage_address_val_felt), *val
        )
            .unwrap_syscall();
    }

    fn positions_mapping_read(self: @EnumerableMap<K, V>, key: @K) -> u32 {
        let storage_base_felt: felt252 = storage_address_from_base(*self.base).into();
        let mut storage_address_val = PedersenTrait::new(storage_base_felt).update('positions');
        let mut serialized_key: Array<felt252> = array![];
        key.serialize(ref serialized_key);
        let mut i = 0;
        let len = serialized_key.len();
        while i < len {
            storage_address_val = storage_address_val.update(*serialized_key.at(i));
            i += 1;
        };
        let storage_address_val_felt = storage_address_val.finalize();
        Store::<
            u32
        >::read(*self.address_domain, storage_base_address_from_felt252(storage_address_val_felt))
            .unwrap_syscall()
    }

    fn update_array_len(ref self: EnumerableMap<K, V>, new_len: @u32) {
        Store::<u32>::write(self.address_domain, self.base, *new_len).unwrap_syscall();
    }

    fn array_append(ref self: EnumerableMap<K, V>, key: @K) {
        let len = Store::<u32>::read(self.address_domain, self.base).unwrap_syscall();
        self.array_write(@len, *key);
        self.update_array_len(@(len + 1));
        self.positions_mapping_write(key, @(len + 1));
    }

    fn array_remove(ref self: EnumerableMap<K, V>, index: @u32) -> bool {
        let len = Store::<u32>::read(self.address_domain, self.base).unwrap_syscall();
        if *index >= len {
            return false;
        }
        let element = self.array_read(index);
        // Remove `element` from `positions` mapping
        self.positions_mapping_write(@element, @0);
        // if element is not the last element, swap with last element and clear the last index
        if *index != len - 1 {
            let last_element = self.array_read(@(len - 1));
            // Updates the position of `last_element` in 'positions' mapping
            self.positions_mapping_write(@last_element, @(*index + 1));
            // Moves last element into 'index' and remove the last element
            self.array_write(index, last_element);
            // Deletes the last element from array
            self.array_write(@(len - 1), Zero::<K>::zero());
        }
        // Decrease the array length
        self.update_array_len(@(len - 1));
        true
    }

    fn array_read(self: @EnumerableMap<K, V>, index: @u32) -> K {
        let storage_base_felt: felt252 = storage_address_from_base(*self.base).into();
        let storage_address_felt = poseidon_hash_span(
            array![storage_base_felt, (*index).into()].span()
        );
        Store::<
            K
        >::read(*self.address_domain, storage_base_address_from_felt252(storage_address_felt))
            .unwrap_syscall()
    }

    fn array_write(ref self: EnumerableMap<K, V>, index: @u32, val: K) {
        let storage_base_felt: felt252 = storage_address_from_base(self.base).into();
        let storage_address_felt = poseidon_hash_span(
            array![storage_base_felt, (*index).into()].span()
        );
        Store::<
            K
        >::write(self.address_domain, storage_base_address_from_felt252(storage_address_felt), val)
            .unwrap_syscall();
    }
}

use core::num::traits::Zero;
use core::pedersen::PedersenTrait;
use core::poseidon::poseidon_hash_span;
use core::hash::{HashStateTrait};
use starknet::storage_access::{
    StorageBaseAddress, storage_address_from_base, storage_base_address_from_felt252
};
use starknet::syscalls::{storage_read_syscall, storage_write_syscall};
use starknet::{Store, SyscallResultTrait, SyscallResult};

const NOT_IMPLEMENTED: felt252 = 'Not implemented';
const INDEX_OUT_OF_BOUNDS: felt252 = 'Index out of bounds!';

#[derive(Copy, Drop)]
pub struct EnumarableMap<K, V> {
    address_domain: u32,
    base: StorageBaseAddress
}

pub impl EnumarableMapStore<
    K, V, +Store<K>, +Drop<K>, +Store<V>, +Drop<V>
> of Store<EnumarableMap<K, V>> {
    #[inline(always)]
    fn read(address_domain: u32, base: StorageBaseAddress) -> SyscallResult<EnumarableMap<K, V>> {
        SyscallResult::Ok(EnumarableMap::<K,V>{ address_domain, base })
    }

    #[inline(always)]
    fn write(
        address_domain: u32, base: StorageBaseAddress, value: EnumarableMap<K, V>
    ) -> SyscallResult<()> {
        SyscallResult::Err(array![NOT_IMPLEMENTED])
    }

    #[inline(always)]
    fn read_at_offset(
        address_domain: u32, base: StorageBaseAddress, offset: u8
    ) -> SyscallResult<EnumarableMap<K, V>> {
        SyscallResult::Err(array![NOT_IMPLEMENTED])
    }
    #[inline(always)]
    fn write_at_offset(
        address_domain: u32, base: StorageBaseAddress, offset: u8, value: EnumarableMap<K, V>
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
    fn get(self: @EnumarableMap<K, V>, key: @K) -> V;
    fn set(ref self: EnumarableMap<K, V>, key: @K, val: @V) -> ();
    fn len(self: @EnumarableMap<K, V>) -> u32;
    fn contains(self: @EnumarableMap<K, V>, key: @K) -> bool;
    fn remove(ref self: EnumarableMap<K, V>, key: @K) -> bool;
    fn at(self: @EnumarableMap<K, V>, index: u32) -> (K, V);
    fn keys(self: @EnumarableMap<K, V>) -> Array<K>;
}

pub impl EnumerableMapImpl<
    K, V, +Drop<K>, +Store<K>, +Serde<K>, +Drop<V>, +Copy<V>, +Copy<K>, +Zero<V>, +Zero<K>, +Store<V>,
> of EnumerableMapTrait<K, V> {
    fn get(self: @EnumarableMap<K, V>, key: @K) -> V {
        EnumarableMapInternalTrait::<K,V>::values_mapping_read(self, key)
    }

    fn set(ref self: EnumarableMap<K, V>, key: @K, val: @V) {
        EnumarableMapInternalTrait::<K,V>::values_mapping_write(ref self, key, val);
        // appends 'key' to array and updates 'position' mapping
        EnumarableMapInternalTrait::<K,V>::array_append(ref self, key);
    }

    fn len(self: @EnumarableMap<K, V>) -> u32 {
        Store::<u32>::read(*self.address_domain, *self.base).unwrap_syscall()
    }

    fn contains(self: @EnumarableMap<K, V>, key: @K) -> bool {
       EnumarableMapInternalTrait::<K,V>::positions_mapping_read(self, key) != 0
    }

    fn remove(ref self: EnumarableMap<K, V>, key: @K) -> bool {
        if !self.contains(key) {
            return false;
        }
        let index = EnumerableMapInternalImpl::<K,V>::positions_mapping_read(@self, key) - 1;
        /////////////////////////////// Deletes `key` from 'values' mapping /////////////////////////////////////
        EnumarableMapInternalTrait::<K,V>::values_mapping_write(ref self, key, @Zero::<V>::zero());
        /////////////////////////////// Deletes `key`` from 'array' and 'positions' mapping /////////////////////
        EnumarableMapInternalTrait::<K,V>::array_remove(ref self, @index)
    }

    fn at(self: @EnumarableMap<K, V>, index: u32) -> (K, V) {
        assert(index < self.len(), INDEX_OUT_OF_BOUNDS);
        let key = EnumarableMapInternalTrait::<K,V>::array_read(self, @index);
        let val = EnumarableMapInternalTrait::<K,V>::values_mapping_read(self, @key);
        (key, val)
    }

    fn keys(self: @EnumarableMap<K,V>) -> Array<K> {
        let mut i = 0;
        let len = self.len();
        let mut keys = array![];
        while i < len {
            let key = EnumarableMapInternalTrait::<K,V>::array_read(self, @i);
            keys.append(key);
            i += 1;
        };
        keys
    }
}

trait EnumarableMapInternalTrait<K,V> {
    fn values_mapping_write(ref self: EnumarableMap<K,V>, key: @K, val: @V);
    fn values_mapping_read(self: @EnumarableMap<K,V>, key: @K) -> V;
    fn positions_mapping_write(ref self: EnumarableMap<K,V>, key: @K, val: @u32);
    fn positions_mapping_read(self: @EnumarableMap<K,V>, key: @K) -> u32;
    fn update_array_len(ref self: EnumarableMap<K,V>, new_len: @u32);
    fn array_append(ref self: EnumarableMap<K,V>, key: @K);
    fn array_remove(ref self: EnumarableMap<K,V>, index: @u32) -> bool;
    fn array_read(self: @EnumarableMap<K,V>, index: @u32) -> K;
    fn array_write(ref self: EnumarableMap<K,V>, index: @u32, val: K);
}

impl EnumerableMapInternalImpl<
    K, V, +Drop<K>, +Store<K>, +Serde<K>, +Drop<V>, +Copy<V>, +Copy<K>, +Zero<V>, +Zero<K>, +Store<V>,
> of EnumarableMapInternalTrait<K, V> {
    fn values_mapping_write(ref self: EnumarableMap<K,V>, key: @K, val: @V) {
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
            self.address_domain,
            storage_base_address_from_felt252(storage_address_val_felt),
            *val
        )
            .unwrap_syscall();  
    }

    fn values_mapping_read(self: @EnumarableMap<K,V>, key: @K) -> V {
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
        >::read(
            *self.address_domain,
            storage_base_address_from_felt252(storage_address_val_felt)
        )
            .unwrap_syscall() 
    }

    fn positions_mapping_write(ref self: EnumarableMap<K,V>, key: @K, val: @u32) {
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
            self.address_domain,
            storage_base_address_from_felt252(storage_address_val_felt),
            *val
        )
            .unwrap_syscall();  
    }

    fn positions_mapping_read(self: @EnumarableMap<K,V>, key: @K) -> u32 {
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
        >::read(
            *self.address_domain,
            storage_base_address_from_felt252(storage_address_val_felt)
        )
            .unwrap_syscall()
    }

    fn update_array_len(ref self: EnumarableMap<K,V>, new_len: @u32) {
        Store::<u32>::write(self.address_domain, self.base, *new_len).unwrap_syscall();
    }

    fn array_append(ref self: EnumarableMap<K,V>, key: @K) {
        let len = Store::<u32>::read(self.address_domain, self.base).unwrap_syscall();
        let storage_base_felt: felt252 = storage_address_from_base(self.base).into();
        let array_storage_address_felt = poseidon_hash_span(
            array![storage_base_felt, len.into()].span()
        );
        Store::<
            K
        >::write(
            self.address_domain, storage_base_address_from_felt252(array_storage_address_felt), *key
        )
            .unwrap_syscall();
        self.positions_mapping_write(key, @(len +1));
        self.update_array_len(@(len + 1));
    }

    fn array_remove(ref self: EnumarableMap<K,V>, index: @u32) -> bool {
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
            /////////// Updates the position of `last_element` in 'positions' mapping ////////////////
            self.positions_mapping_write(@last_element, @(*index+1));
            /////////// Moves last element into 'index' and remove the last element ///////////
            self.array_write(index, last_element);
            // Deletes the last element from array
            self.array_write(@(len -1), Zero::<K>::zero());
        }
        // Decrease the array length
        self.update_array_len(@(len - 1));
        true
    }

    fn array_read(self: @EnumarableMap<K,V>, index: @u32) -> K {
        let storage_base_felt: felt252 = storage_address_from_base(*self.base).into();
        let storage_address_felt = poseidon_hash_span(
            array![storage_base_felt, (*index).into()].span()
        );
        Store::<
            K
        >::read(
            *self.address_domain,
            storage_base_address_from_felt252(storage_address_felt)
        ).unwrap_syscall()
    }

    fn array_write(ref self: EnumarableMap<K,V>, index: @u32, val: K) {
        let storage_base_felt: felt252 = storage_address_from_base(self.base).into();
        let storage_address_felt = poseidon_hash_span(
            array![storage_base_felt, (*index).into()].span()
        );
         Store::<
            K
        >::write(
            self.address_domain,
            storage_base_address_from_felt252(storage_address_felt),
            val
        ).unwrap_syscall();
    }
}

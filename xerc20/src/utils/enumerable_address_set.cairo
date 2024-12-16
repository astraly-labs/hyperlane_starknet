use starknet::{
    ContractAddress,
    storage::{
        Map, Mutable, MutableVecTrait, StoragePath, StoragePathEntry, StoragePointerReadAccess,
        StoragePointerWriteAccess, Vec, VecTrait,
    },
};

///! Append-only set
#[starknet::storage_node]
pub struct EnumerableAddressSet {
    values: Vec<ContractAddress>,
    positions: Map<ContractAddress, u64>,
}

pub trait EnumerableAddressSetTrait {
    fn contains(self: StoragePath<EnumerableAddressSet>, value: ContractAddress) -> bool;
    fn len(self: StoragePath<EnumerableAddressSet>) -> u64;
    fn at(self: StoragePath<EnumerableAddressSet>, index: u64) -> ContractAddress;
    fn values(self: StoragePath<EnumerableAddressSet>) -> Array<ContractAddress>;
}

impl EnumerableAddressSetImpl of EnumerableAddressSetTrait {
    fn contains(self: StoragePath<EnumerableAddressSet>, value: ContractAddress) -> bool {
        self.positions.entry(value).read() > 0
    }
    fn len(self: StoragePath<EnumerableAddressSet>) -> u64 {
        self.values.len()
    }
    fn at(self: StoragePath<EnumerableAddressSet>, index: u64) -> ContractAddress {
        self.values.at(index).read()
    }
    fn values(self: StoragePath<EnumerableAddressSet>) -> Array<ContractAddress> {
        let mut addresses = array![];
        let length = self.values.len();
        for i in 0..length {
            addresses.append(self.values.at(i).read());
        };
        addresses
    }
}

pub trait MutableEnumerableAddressSetTrait {
    fn add(self: StoragePath<Mutable<EnumerableAddressSet>>, value: ContractAddress);
    fn contains(self: StoragePath<Mutable<EnumerableAddressSet>>, value: ContractAddress) -> bool;
    fn len(self: StoragePath<Mutable<EnumerableAddressSet>>) -> u64;
    fn at(self: StoragePath<Mutable<EnumerableAddressSet>>, index: u64) -> ContractAddress;
    fn values(self: StoragePath<Mutable<EnumerableAddressSet>>) -> Array<ContractAddress>;
}

impl MutableEnumerableAddressSetTraitImpl of MutableEnumerableAddressSetTrait {
    fn add(self: StoragePath<Mutable<EnumerableAddressSet>>, value: ContractAddress) {
        let position_storage_path = self.positions.entry(value);
        assert(position_storage_path.read() == 0, 'Value already member of the set');
        self.values.append().write(value);
        position_storage_path.write(self.values.len());
    }

    fn contains(self: StoragePath<Mutable<EnumerableAddressSet>>, value: ContractAddress) -> bool {
        self.positions.entry(value).read() > 0
    }

    fn len(self: StoragePath<Mutable<EnumerableAddressSet>>) -> u64 {
        self.values.len()
    }

    fn at(self: StoragePath<Mutable<EnumerableAddressSet>>, index: u64) -> ContractAddress {
        self.values.at(index).read()
    }

    fn values(self: StoragePath<Mutable<EnumerableAddressSet>>) -> Array<ContractAddress> {
        let mut addresses = array![];
        let length = self.values.len();
        for i in 0..length {
            addresses.append(self.values.at(i).read());
        };
        addresses
    }
}

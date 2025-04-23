use cainome::cairo_serde::EthAddress;
use ethers::utils::hex::FromHex;
use k256::{
    ecdsa::{RecoveryId, SigningKey, VerifyingKey},
    elliptic_curve::rand_core::OsRng,
};
use starknet::core::types::Felt;

#[derive(Clone)]
pub struct TestValidator {
    pub priv_key: SigningKey,
    pub pub_key: VerifyingKey,
}

#[allow(dead_code)]
impl TestValidator {
    fn random() -> Self {
        let priv_key = SigningKey::random(&mut OsRng);
        Self {
            pub_key: VerifyingKey::from(&priv_key),
            priv_key,
        }
    }

    fn from_key(priv_key_hex: &str) -> Self {
        let h = <Vec<u8>>::from_hex(priv_key_hex).unwrap();
        let priv_key = SigningKey::from_bytes(h.as_slice().into()).unwrap();
        let pub_key = VerifyingKey::from(&priv_key);

        Self { priv_key, pub_key }
    }

    pub fn eth_addr(&self) -> EthAddress {
        let hash = keccak256_hash(&self.pub_key.to_encoded_point(false).as_bytes()[1..]);

        let mut bytes = [0u8; 20];
        bytes.copy_from_slice(&hash.as_slice()[12..]);

        EthAddress(Felt::from_bytes_be_slice(&bytes))
    }

    pub fn sign(&self, digest: [u8; 32]) -> (Felt, RecoveryId) {
        let (sign, recov_id) = self.priv_key.sign_prehash_recoverable(&digest).unwrap();

        (
            Felt::from_bytes_be_slice(sign.to_bytes().as_slice()),
            recov_id,
        )
    }
}

#[derive(Clone)]
pub struct TestValidators {
    pub domain: u32,
    pub validators: Vec<TestValidator>,
    pub threshold: u8,
}

impl TestValidators {
    pub fn new(domain: u32, num: u8, threshold: u8) -> Self {
        assert!(num >= threshold);

        let validators = vec![0; num as usize]
            .into_iter()
            .map(|_| TestValidator::random())
            .collect::<Vec<_>>();

        Self {
            domain,
            validators,
            threshold,
        }
    }

    #[allow(dead_code)]
    pub fn from_keys(domain: u32, keys: &[String], threshold: u8) -> Self {
        assert!(keys.len() as u8 >= threshold);

        let validators = keys
            .iter()
            .map(|k| TestValidator::from_key(k))
            .collect::<Vec<_>>();

        Self {
            domain,
            validators,
            threshold,
        }
    }
}

pub fn keccak256_hash(bz: &[u8]) -> Vec<u8> {
    use sha3::{Digest, Keccak256};

    let mut hasher = Keccak256::new();
    hasher.update(bz);
    let hash = hasher.finalize().to_vec();

    hash
}

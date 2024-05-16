use cainome::cairo_serde::EthAddress;
use ethers::types::{Address, H160};
use ethers::utils::hex::FromHex;
use k256::{
    ecdsa::{RecoveryId, SigningKey, VerifyingKey},
    elliptic_curve::rand_core::OsRng,
};
use starknet::core::types::FieldElement;

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
        EthAddress(
            FieldElement::from_byte_slice_be(&self.pub_key.to_encoded_point(false).as_bytes())
                .unwrap(),
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

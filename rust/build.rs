use ethers::prelude::Abigen;
use std::{
    collections::HashMap,
    env::current_dir,
    fs,
    path::{Path, PathBuf},
};

fn check_path_exists(path: &Path) {
    if !path.exists() {
        panic!("Path does not exist: {:?}", path);
    }
}

fn generate_eth_bind(name: &str, abi_file: &str, bind_out: PathBuf) {
    // Check if the ABI file exists
    let abi_file_path = Path::new(abi_file);
    check_path_exists(abi_file_path);

    // Remove output file if it exists
    if bind_out.exists() {
        fs::remove_file(&bind_out).unwrap();
    }

    // Generate Ethereum bindings
    Abigen::new(name, abi_file)
        .unwrap()
        .generate()
        .unwrap()
        .write_to_file(bind_out)
        .unwrap();
}

fn generate_strk_bind(name: &str, abi_file: &str, bind_out: PathBuf) {
    // Check if the ABI file exists
    let abi_file_path = Path::new(abi_file);
    check_path_exists(abi_file_path);

    // Remove output file if it exists
    if bind_out.exists() {
        fs::remove_file(&bind_out).unwrap();
    }

    let mut aliases = HashMap::new();
    aliases.insert(
        String::from("openzeppelin::access::ownable::ownable::OwnableComponent::Event"),
        String::from("OwnableCptEvent"),
    );
    aliases.insert(
        String::from("openzeppelin::upgrades::upgradeable::UpgradeableComponent::Event"),
        String::from("UpgradeableCptEvent"),
    );
    aliases.insert(
        String::from("contracts::client::mailboxclient_component::MailboxclientComponent::Event"),
        String::from("MailboxclientEvent"),
    );
    // aliases.insert(
    //     String::from("OwnableComponent::Event::OwnershipTransferred"),
    //     String::from("OwnableOwnershipTransferred"),
    // );
    // aliases.insert(
    //     String::from("OwnableComponent::Event::OwnershipTransferStarted"),
    //     String::from("OwnableOwnershipTransferStarted"),
    // );
    // aliases.insert(
    //     String::from("UpgradeableComponent::Event::Upgraded"),
    //     String::from("UpgradeableUpgraded"),
    // );
    // aliases.insert(
    //     String::from("Event"), 
    //     format!("{}Event", name)
    // );
    // aliases.insert(
    //     String::from("OwnableEvent"),
    //     String::from("BoxedOwnableEvent"),
    // );
    // aliases.insert(
    //     String::from("UpgradeableEvent"),
    //     String::from("BoxedUpgradeableEvent"),
    // );
    // aliases.insert(
    //     String::from("MailboxclientEvent"),
    //     String::from("BoxedMailboxclientEvent"),
    // );
    

    let abigen = cainome::rs::Abigen::new(name, abi_file)
        .with_derives(vec!["Debug".to_string()])
        .with_types_aliases(aliases);

    abigen
        .generate()
        .expect("Fail to generate bindings")
        .write_to_file(bind_out.to_str().expect("valid utf8 path"))
        .expect("Fail to write bindings to file");
}

fn main() {
    // Generate Ethereum bindings
    let eth_abi_base = current_dir().unwrap().join("abis");
    let eth_bind_base = current_dir()
        .unwrap()
        .join("tests")
        .join("contracts/eth/bind");

    // Check if the Ethereum ABI directory exists
    check_path_exists(&eth_abi_base);
    check_path_exists(&eth_bind_base);

    let eth_deployments = [
        ("Mailbox", "mailbox"),
        ("FastHypERC20", "fast_hyp_erc20"),
        ("FastHypERC20Collateral", "fast_hyp_erc20_collateral"),
        ("TestMultisigIsm", "test_mock_ism"),
        ("TestRecipient", "test_mock_msg_receiver"),
        ("TestMerkleTreeHook", "test_merkle_tree_hook"),
    ];

    for (abi_file, bind_out) in eth_deployments {
        generate_eth_bind(
            abi_file,
            eth_abi_base
                .join(format!("{abi_file}.json"))
                .to_str()
                .unwrap(),
            eth_bind_base.join(format!("{bind_out}.rs")),
        );
    }

    // Generate Starknet bindings
    let strk_abi_base = current_dir()
        .unwrap()
        .parent() // Move one directory up to source directory
        .unwrap()
        .join("cairo")
        .join("target")
        .join("dev");
    let strk_bind_base = current_dir()
        .unwrap()
        .join("tests")
        .join("contracts/strk/bind");

    // Check if the Starknet ABI directory exists
    check_path_exists(&strk_abi_base);
    check_path_exists(&strk_bind_base);

    let strk_deployments = [
        ("mailbox", "mailbox"),
        ("domain_routing_ism", "routing"),
        ("ism", "ism"),
        ("messageid_multisig_ism", "multisig_ism"),
        ("validator_announce", "validator_announce"),
    ];

    for (abi_file, bind_out) in strk_deployments {
        generate_strk_bind(
            abi_file,
            strk_abi_base
                .join(format!("contracts_{abi_file}.contract_class.json"))
                .to_str()
                .unwrap(),
            strk_bind_base.join(format!("{bind_out}.rs")),
        );
    }
}

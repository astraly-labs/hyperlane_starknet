use crate::{common::E18, e2e::common::{DAI_NAME, DAI_SYMBOL, setup_base}};
use openzeppelin_access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};
use openzeppelin_token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
use xerc20::{
    factory::interface::IXERC20FactoryDispatcherTrait,
    lockbox::interface::{XERC20LockboxABIDispatcher, XERC20LockboxABIDispatcherTrait},
    xerc20::interface::XERC20ABIDispatcherTrait,
};

#[test]
//#[fork("mainnet")]
#[ignore]
fn test_deploy() {
    let setup = setup_base();

    let erc20_dispatcher = ERC20ABIDispatcher { contract_address: setup.xerc20.contract_address };
    let ownable_dispatcher = IOwnableDispatcher { contract_address: setup.xerc20.contract_address };

    assert!(ownable_dispatcher.owner() == setup.owner);
    assert!(erc20_dispatcher.name() == DAI_NAME());
    assert!(erc20_dispatcher.symbol() == DAI_SYMBOL());
    assert!(setup.xerc20.factory() == setup.factory.contract_address);
    assert!(setup.lockbox.xerc20() == setup.xerc20.contract_address);
    assert!(setup.lockbox.erc20() == setup.dai.contract_address);
    assert!(setup.xerc20.burning_max_limit_of(setup.test_minter) == 50 * E18);
    assert!(setup.xerc20.minting_max_limit_of(setup.test_minter) == 100 * E18);
}

#[test]
//#[fork("mainnet")]
#[ignore]
fn test_deploy_lockbox() {
    let setup = setup_base();

    let limits = array![].span();
    let minters = array![].span();

    let xerc20_token = setup.factory.deploy_xerc20("Test", "TST", limits, limits, minters);
    let lockbox = setup.factory.deploy_lockbox(xerc20_token, setup.dai.contract_address);
    let lockbox_dispatcher = XERC20LockboxABIDispatcher { contract_address: lockbox };

    assert!(lockbox_dispatcher.xerc20() == xerc20_token);
    assert!(lockbox_dispatcher.erc20() == setup.dai.contract_address);
}

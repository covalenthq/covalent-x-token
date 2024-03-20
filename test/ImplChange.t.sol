// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {CovalentXToken} from "src/CovalentXToken.sol";
import {DefaultEmissionManager} from "src/DefaultEmissionManager.sol";
import {TestEmissionManager} from "src/utils/TestEmissionManager.sol";
import {CovalentMigration} from "src/CovalentMigration.sol";
import {ERC20PresetMinterPauser} from "openzeppelin-contracts/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import {
    ProxyAdmin,
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/Console2.sol";

contract ChangeImplementation is Test {
    error InvalidAddress();

    function testChangeImplementation() public {
        address deployerAdmin = makeAddr("deployerAdmin");
        vm.startPrank(deployerAdmin);
        ProxyAdmin admin = new ProxyAdmin();
        admin.transferOwnership(deployerAdmin);
        address treasury = makeAddr("deployerAdmin");
        address migrationProxy = makeAddr("migrationProxy");

        address emissionManagerImplementation = address(new DefaultEmissionManager(migrationProxy, treasury));
        address emissionManagerProxy =
            address(new TransparentUpgradeableProxy(address(emissionManagerImplementation), address(admin), ""));
        console2.log(
            "New mintable supply after 1 year:",
            block.timestamp,
            DefaultEmissionManager(emissionManagerProxy).inflatedSupplyAfter(block.timestamp + 365 days)
        );

        CovalentXToken CXT =
            new CovalentXToken(migrationProxy, emissionManagerProxy, deployerAdmin, deployerAdmin);
        DefaultEmissionManager emissionManager = DefaultEmissionManager(emissionManagerProxy);

        skip(183 days);
        console2.log("After 180 days ", block.timestamp, DefaultEmissionManager(emissionManagerProxy).startTimestamp());
        DefaultEmissionManager(emissionManagerProxy).initialize(address(CXT), deployerAdmin);
        console2.log("After init ", DefaultEmissionManager(emissionManagerProxy).startTimestamp());
        uint256 initialTotalSupply = CXT.totalSupply();
        address newImplementation = address(new TestEmissionManager(migrationProxy, treasury));
        admin.upgrade(ITransparentUpgradeableProxy(emissionManagerProxy), newImplementation);

        // CXT.updateMintCap acc
        // @dev @note updateMintCap in CXT token contract must be called accordingly.
        uint256 delay = 90 days;
        // emissionManager.mint();
        // inflatedSupplyAfter
        skip(delay);
        console2.log("delay", delay);
        console2.log(
            "Updated mintable supply after 1 year:",
            DefaultEmissionManager(emissionManagerProxy).startTimestamp(),
            block.timestamp,
            DefaultEmissionManager(emissionManagerProxy).inflatedSupplyAfter(delay)
        );

        emissionManager.mint();
        console2.log("initial total supply:", initialTotalSupply, CXT.totalSupply());
        console2.log("new implementation:", newImplementation);
    }
}

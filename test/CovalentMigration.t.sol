// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {CovalentXToken} from "src/CovalentXToken.sol";
import {CovalentMigration} from "src/CovalentMigration.sol";
import {DefaultEmissionManager} from "src/DefaultEmissionManager.sol";

import {ERC20PresetMinterPauser} from "openzeppelin-contracts/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import {
    TransparentUpgradeableProxy, ProxyAdmin
} from "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import {SigUtils} from "test/SigUtils.t.sol";
import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/Console2.sol";

contract CovalentMigrationTest is Test {
    CovalentXToken public CXT;
    CovalentMigration public migration;
    SigUtils public sigUtils;
    ProxyAdmin public admin;
    address public treasury;
    address public governance;
    DefaultEmissionManager public emissionManager;

    function setUp() external {
        treasury = makeAddr("treasury");
        governance = makeAddr("governance");
        admin = new ProxyAdmin();

        migration = CovalentMigration(
            address(
                new TransparentUpgradeableProxy(
                    address(new CovalentMigration()),
                    address(admin),
                    abi.encodeWithSelector(CovalentMigration.initialize.selector)
                )
            )
        );
        emissionManager = new DefaultEmissionManager(address(migration), treasury);
        CXT = new CovalentXToken(
            address(migration),
            address(emissionManager),
            governance,
            makeAddr("permit2revoker")
        );
        sigUtils = new SigUtils(CXT.DOMAIN_SEPARATOR());

        migration.setToken(address(CXT)); // deployer sets token
        migration.transferOwnership(governance); // deployer transfers ownership
        vm.prank(governance);
        migration.acceptOwnership(); // governance accepts ownership
    }

    function test_Deployment() external {
        console2.log(CXT.balanceOf(address(migration)));
        address[] memory recipients = new address[](3);
        recipients[0] = makeAddr("recipient1");
        recipients[1] = makeAddr("recipient2");
        recipients[2] = governance;
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 1000;
        amounts[1] = 2000;
        amounts[2] = (1_000_000_000 * 10 ** 18) - 3000;
        vm.prank(governance);
        migration.batchDistribute(recipients, amounts);
        assertEq(CXT.balanceOf(recipients[0]), 1000);
        assertEq(CXT.balanceOf(recipients[1]), 2000);
        assertEq(CXT.balanceOf(governance), amounts[2]);
    }
}

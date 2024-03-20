// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Script, stdJson, console2} from "forge-std/Script.sol";
import {CovalentMigration} from "src/CovalentMigration.sol";

contract DistributeTokens is Script {
    address public deployerAdmin;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        deployerAdmin = vm.addr(deployerPrivateKey);
        // address migrationProxy = address(0x0);
        // CovalentMigration migration = CovalentMigration(migrationProxy);
        // address[] memory recipients = new address[](1);
        // recipients[0] = deployerAdmin;
        // uint256[] memory amounts = new uint256[](1);
        // amounts[0] = 1000;
        // Migration.batchDistribute(recipients, amounts);
    }
}

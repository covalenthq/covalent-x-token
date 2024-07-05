// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import {CovalentXToken} from "src/CovalentXToken.sol";
import {CovalentMigration} from "src/CovalentMigration.sol";
import {ProxyAdmin, TransparentUpgradeableProxy} from "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";

contract DeployCXT is Script {
    address public deployerAdmin;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        deployerAdmin = vm.addr(deployerPrivateKey);
        address protocolCouncil = address(deployerAdmin);
        address emergencyCouncil = address(deployerAdmin);
        vm.startBroadcast(deployerPrivateKey);

        ProxyAdmin admin = new ProxyAdmin();
        admin.transferOwnership(emergencyCouncil);

        address migrationImplementation = address(new CovalentMigration());

        address migrationProxy = address(
            new TransparentUpgradeableProxy(
                migrationImplementation,
                address(admin),
                abi.encodeWithSelector(CovalentMigration.initialize.selector)
            )
        );

        CovalentXToken covalentXToken = new CovalentXToken(
            migrationProxy,
            address(0), // Placeholder for emissionManagerProxy
            protocolCouncil,
            emergencyCouncil
        );

        CovalentMigration(migrationProxy).setToken(address(covalentXToken));

        CovalentMigration(migrationProxy).transferOwnership(protocolCouncil); // governance needs to accept the ownership transfer

        console.log("Covalent Network Token address: ", address(covalentXToken), "\n");
        console.log("Covalent Migration address: ", address(migrationProxy), "\n");
        console.log("Admin address: ", address(admin), "\n");
        vm.stopBroadcast();
    }
}

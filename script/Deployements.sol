// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import {CovalentXToken} from "src/CovalentXToken.sol";
import {CovalentMigration} from "src/CovalentMigration.sol";
import {DefaultEmissionManager} from "src/DefaultEmissionManager.sol";
import {ProxyAdmin, TransparentUpgradeableProxy} from "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";

contract Deploy is Script {
    address public deployerAdmin;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        deployerAdmin = vm.addr(deployerPrivateKey);
        address treasury = address(deployerAdmin);
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

        address emissionManagerImplementation = address(new DefaultEmissionManager(migrationProxy, treasury));
        address emissionManagerProxy = address(
            new TransparentUpgradeableProxy(address(emissionManagerImplementation), address(admin), "")
        );

        CovalentXToken covalentXToken = new CovalentXToken(
            migrationProxy,
            emissionManagerProxy,
            protocolCouncil,
            emergencyCouncil
        );

        DefaultEmissionManager(emissionManagerProxy).initialize(address(covalentXToken), protocolCouncil);

        CovalentMigration(migrationProxy).setToken(address(covalentXToken));

        CovalentMigration(migrationProxy).transferOwnership(protocolCouncil); // governance needs to accept the ownership transfer

        console.log("Covalent Network Token address: ", address(covalentXToken), "\n");
        console.log("Covalent Migration address: ", address(migrationProxy), "\n");
        console.log("Default Emission Manager address: ", address(emissionManagerProxy), "\n");
        console.log("Admin address: ", address(admin), "\n");
        vm.stopBroadcast();
    }
}

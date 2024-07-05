// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import {DefaultEmissionManager} from "src/DefaultEmissionManager.sol";
import {CovalentXToken} from "src/CovalentXToken.sol";
import {ProxyAdmin, TransparentUpgradeableProxy} from "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";

contract DeployEmissionManager is Script {
    address public deployerAdmin;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        deployerAdmin = vm.addr(deployerPrivateKey);
        address treasury = address(deployerAdmin);
        address protocolCouncil = address(deployerAdmin);
        vm.startBroadcast(deployerPrivateKey);

        ProxyAdmin admin = new ProxyAdmin();
        admin.transferOwnership(protocolCouncil);

        address migrationProxy = 0x47ab75e2F99aE4f4149FDB81A2278464289b8DE1;
        address covalentXTokenAddress = 0x0996faFbc0A9835Ed2C786EB53913Ec11304d56A;
        CovalentXToken covalentXToken = CovalentXToken(covalentXTokenAddress);

        address emissionManagerImplementation = address(new DefaultEmissionManager(migrationProxy, treasury));
        address emissionManagerProxy = address(
            new TransparentUpgradeableProxy(address(emissionManagerImplementation), address(admin), "")
        );

        DefaultEmissionManager(emissionManagerProxy).initialize(address(covalentXToken), protocolCouncil);

        console.log("Default Emission Manager address: ", address(emissionManagerProxy), "\n");
        console.log("Admin address: ", address(admin), "\n");
        vm.stopBroadcast();
    }
}

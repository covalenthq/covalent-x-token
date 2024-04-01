// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import {CovalentXToken} from "src/CovalentXToken.sol";
import {CovalentMigration} from "src/CovalentMigration.sol";
import {TestEmissionManager} from "src/utils/TestEmissionManager.sol";
import {ProxyAdmin, ITransparentUpgradeableProxy, TransparentUpgradeableProxy} from "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";

contract Deploy is Script {
    address public deployerAdmin;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        deployerAdmin = vm.addr(deployerPrivateKey);
        address treasury = address(deployerAdmin);
        address migrationProxy = 0x136FE32D4a0Bc1B4f4Ef7100A2a6ee17593b8E26;
        address _admin = 0x41d906E7D70D6dc15b8999a7EC56df849cc55F98;
        address emissionManagerProxy = 0xf2C77153A570B6dB9ed323E880E801D5529b99C3;
        CovalentXToken CXT = CovalentXToken(0x5026E6Db8CE67BAfFB8df2d545EC727bFf47c16f);
        //address newImpl = 0xAa266081FDF4421cABFE6a26D8fc9ba870679911;
        //address newImpl = 0x2913A6e706589A92C5f10ef8b07259CafA95B3b5;
        vm.startBroadcast(deployerPrivateKey);
        /*
        Covalent Migration address:  0x136FE32D4a0Bc1B4f4Ef7100A2a6ee17593b8E26 

        Default Emission Manager address:  0xf2C77153A570B6dB9ed323E880E801D5529b99C3 

        Admin address:  0x41d906E7D70D6dc15b8999a7EC56df849cc55F98 */
        ProxyAdmin admin = ProxyAdmin(_admin);
        CXT.updateMintCap(6.35e18);
        //address newImplementation = address(new TestEmissionManager(migrationProxy, treasury));
        //admin.upgrade(ITransparentUpgradeableProxy(emissionManagerProxy), newImplementation);
        TestEmissionManager emissionManager = TestEmissionManager(emissionManagerProxy);
        //console.log("newImplementation: ", newImplementation, "\n");
        emissionManager.mint();
        console.log(CXT.mintPerSecondCap(), CXT.lastMint(), block.timestamp);
        uint256 timeElapsed = block.timestamp - emissionManager.startTimestamp();
        console.log("Start time stamp", emissionManager.startTimestamp());
        console.log(emissionManager.inflatedSupplyAfter(timeElapsed));
        console2.log("initial total supply:", CXT.totalSupply());
        //console2.log("new implementation:", newImplementation);
        vm.stopBroadcast();
    }
}

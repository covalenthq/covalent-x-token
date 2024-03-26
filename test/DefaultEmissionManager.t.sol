// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {CovalentXToken} from "src/CovalentXToken.sol";
import {DefaultEmissionManager} from "src/DefaultEmissionManager.sol";
import {CovalentMigration} from "src/CovalentMigration.sol";
import {ERC20PresetMinterPauser} from "openzeppelin-contracts/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import {ProxyAdmin, TransparentUpgradeableProxy} from "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/Console2.sol";

contract DefaultEmissionManagerTest is Test {
    error InvalidAddress();

    CovalentXToken public CXT;
    CovalentMigration public migration;
    address public treasury;
    address public governance;
    DefaultEmissionManager public emissionManager;
    DefaultEmissionManager public emissionManagerImplementation;

    // precision accuracy due to log2 approximation is up to the first 5 digits
    uint256 private constant _MAX_PRECISION_DELTA = 1e18;

    string[] internal inputs = new string[](4);

    function setUp() external {
        treasury = makeAddr("treasury");
        governance = makeAddr("governance");
        ProxyAdmin admin = new ProxyAdmin();
        migration = CovalentMigration(
            address(
                new TransparentUpgradeableProxy(
                    address(new CovalentMigration()),
                    address(admin),
                    abi.encodeWithSelector(CovalentMigration.initialize.selector)
                )
            )
        );
        emissionManagerImplementation = new DefaultEmissionManager(address(migration), treasury);
        emissionManager = DefaultEmissionManager(
            address(new TransparentUpgradeableProxy(address(emissionManagerImplementation), address(admin), ""))
        );
        CXT = new CovalentXToken(address(migration), address(emissionManager), governance, makeAddr("permit2revoker"));
        migration.setToken(address(CXT)); // deployer sets token
        migration.transferOwnership(governance);
        vm.prank(governance);
        migration.acceptOwnership();
        emissionManager.initialize(address(CXT), governance);

        inputs[0] = "node";
        inputs[1] = "test/util/calc.js";
    }

    function testRevert_Initialize() external {
        vm.expectRevert("Initializable: contract is already initialized");
        emissionManager.initialize(address(0), address(0));
    }

    function test_Deployment() external {
        assertEq(address(emissionManager.token()), address(CXT));
        assertEq(emissionManager.treasury(), treasury);
        assertEq(emissionManager.owner(), governance);
        assertEq(CXT.allowance(address(emissionManager), address(migration)), type(uint256).max);
        assertEq(emissionManager.START_SUPPLY(), 1_000_000_000e18);
        assertEq(CXT.totalSupply(), 1_000_000_000e18);
    }

    function test_InvalidDeployment() external {
        address _CXT = makeAddr("CXT");
        address _governance = makeAddr("governance");
        address _migration = makeAddr("migration");
        address _treasury = makeAddr("treasury");

        address proxy = address(
            new TransparentUpgradeableProxy(
                address(new DefaultEmissionManager(address(migration), treasury)),
                msg.sender,
                ""
            )
        );

        vm.prank(address(0x1337));
        vm.expectRevert();
        DefaultEmissionManager(proxy).initialize(_CXT, _governance);

        vm.expectRevert(InvalidAddress.selector);
        DefaultEmissionManager(proxy).initialize(_CXT, address(0));
        vm.expectRevert(InvalidAddress.selector);
        DefaultEmissionManager(proxy).initialize(address(0), _governance);
        vm.expectRevert(InvalidAddress.selector);
        DefaultEmissionManager(proxy).initialize(address(0), address(0));

        vm.expectRevert(InvalidAddress.selector);
        new DefaultEmissionManager(address(0), _treasury);
        vm.expectRevert(InvalidAddress.selector);
        new DefaultEmissionManager(_migration, address(0));
    }

    function test_ImplementationCannotBeInitialized() external {
        vm.expectRevert("Initializable: contract is already initialized");
        DefaultEmissionManager(address(emissionManagerImplementation)).initialize(address(0), address(0));
        vm.expectRevert("Initializable: contract is already initialized");
        DefaultEmissionManager(address(emissionManager)).initialize(address(0), address(0));
    }

    function test_Mint() external {
        emissionManager.mint();
        // timeElapsed is zero, so no minting
        assertEq(CXT.balanceOf(treasury), 0);
    }

    function test_MintDelay(uint128 delay) external {
        vm.assume(delay <= 10 * 365 days);
        uint256 initialTotalSupply = CXT.totalSupply();

        skip(delay);

        emissionManager.mint();

        inputs[2] = vm.toString(delay);
        inputs[3] = vm.toString(initialTotalSupply);
        uint256 newSupply = abi.decode(vm.ffi(inputs), (uint256));

        assertApproxEqAbs(newSupply, CXT.totalSupply(), _MAX_PRECISION_DELTA);
        uint256 totalAmtMinted = CXT.totalSupply() - initialTotalSupply;
        assertEq(CXT.balanceOf(treasury), totalAmtMinted);
    }

    function test_MintDelayTwice(uint128 delay) external {
        vm.assume(delay <= 5 * 365 days && delay > 0);

        uint256 initialTotalSupply = CXT.totalSupply();

        skip(delay);
        emissionManager.mint();

        inputs[2] = vm.toString(delay);
        inputs[3] = vm.toString(initialTotalSupply);
        uint256 newSupply = abi.decode(vm.ffi(inputs), (uint256));

        assertApproxEqAbs(newSupply, CXT.totalSupply(), _MAX_PRECISION_DELTA);
        uint256 balance = (CXT.totalSupply() - initialTotalSupply);

        assertEq(CXT.balanceOf(treasury), balance);

        initialTotalSupply = CXT.totalSupply(); // for the new run
        skip(delay);
        emissionManager.mint();

        inputs[2] = vm.toString(delay * 2);
        inputs[3] = vm.toString(initialTotalSupply);
        newSupply = abi.decode(vm.ffi(inputs), (uint256));

        assertApproxEqAbs(newSupply, CXT.totalSupply(), _MAX_PRECISION_DELTA);
        uint256 totalAmtMinted = CXT.totalSupply() - initialTotalSupply;

        balance += totalAmtMinted;

        assertEq(CXT.balanceOf(treasury), balance);
    }

    function test_MintDelayAfterNCycles(uint128 delay, uint8 cycles) external {
        vm.assume(delay * uint256(cycles) <= 10 * 365 days && delay > 0 && cycles < 30);

        uint256 balance;

        for (uint256 cycle; cycle < cycles; cycle++) {
            uint256 initialTotalSupply = CXT.totalSupply();

            skip(delay);
            emissionManager.mint();

            inputs[2] = vm.toString(delay * (cycle + 1));
            inputs[3] = vm.toString(initialTotalSupply);
            uint256 newSupply = abi.decode(vm.ffi(inputs), (uint256));

            assertApproxEqAbs(newSupply, CXT.totalSupply(), _MAX_PRECISION_DELTA);
            uint256 totalAmtMinted = CXT.totalSupply() - initialTotalSupply;

            balance += totalAmtMinted;

            assertEq(CXT.balanceOf(treasury), balance);
        }
    }

    function test_InflatedSupplyAfter(uint256 delay) external {
        vm.assume(delay != 0 && delay <= 10 * 365 days);
        inputs[2] = vm.toString(delay);
        inputs[3] = vm.toString(CXT.totalSupply());
        uint256 newSupply = abi.decode(vm.ffi(inputs), (uint256));
        assertApproxEqAbs(newSupply, emissionManager.inflatedSupplyAfter(block.timestamp + delay), 1e20);
    }
}

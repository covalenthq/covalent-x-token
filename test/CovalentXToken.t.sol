// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {ICovalentXToken} from "src/interfaces/ICovalentXToken.sol";
import {IPermit2} from "src/interfaces/IPermit2.sol";
import {CovalentXToken} from "src/CovalentXToken.sol";
import {DefaultEmissionManager} from "src/DefaultEmissionManager.sol";
import {TransparentUpgradeableProxy, ProxyAdmin} from "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import {Test} from "forge-std/Test.sol";

contract CovalentXTokenTest is Test {
    event Permit2AllowanceUpdated(bool enabled);

    CovalentXToken public CXT;
    address public migration;
    address public treasury;
    address public protocolCouncil;
    address public emergencyCouncil;
    DefaultEmissionManager public emissionManager;
    uint256 public mintPerSecondCap = 2.5e18;
    bytes32 public constant _PERMIT_SINGLE_TYPEHASH =
        keccak256(
            "PermitSingle(PermitDetails details,address spender,uint256 sigDeadline)PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)"
        );
    bytes32 public constant _PERMIT_DETAILS_TYPEHASH =
        keccak256("PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)");

    function setUp() external {
        uint256 forkId = vm.createFork(vm.envString("MAINNET_RPC_URL"), 19610930);
        vm.selectFork(forkId);
        migration = makeAddr("migration");
        treasury = makeAddr("treasury");
        protocolCouncil = makeAddr("protocolCouncil");
        emergencyCouncil = makeAddr("emergencyCouncil");
        ProxyAdmin admin = new ProxyAdmin();
        emissionManager = DefaultEmissionManager(
            address(
                new TransparentUpgradeableProxy(
                    address(new DefaultEmissionManager(migration, treasury)),
                    address(admin),
                    ""
                )
            )
        );
        CXT = new CovalentXToken(migration, address(emissionManager), protocolCouncil, emergencyCouncil);
        emissionManager.initialize(address(CXT), msg.sender);
    }

    function test_Deployment(address owner) external {
        assertEq(CXT.name(), "Covalent X Token");
        assertEq(CXT.symbol(), "CXT");
        assertEq(CXT.decimals(), 18);
        assertEq(CXT.totalSupply(), 1000000000 * 10 ** 18);
        assertEq(CXT.balanceOf(migration), 1000000000 * 10 ** 18);
        assertEq(CXT.balanceOf(treasury), 0);
        assertTrue(CXT.permit2Enabled());
        assertEq(CXT.allowance(owner, CXT.PERMIT2()), type(uint256).max);

        // only protocolCouncil has DEFAULT_ADMIN_ROLE
        assertTrue(CXT.hasRole(CXT.DEFAULT_ADMIN_ROLE(), protocolCouncil));
        assertEq(CXT.getRoleMemberCount(CXT.DEFAULT_ADMIN_ROLE()), 1, "DEFAULT_ADMIN_ROLE incorrect assignees");
        // only protocolCouncil has CAP_MANAGER_ROLE
        assertTrue(CXT.hasRole(CXT.CAP_MANAGER_ROLE(), protocolCouncil));
        assertEq(CXT.getRoleMemberCount(CXT.CAP_MANAGER_ROLE()), 1, "CAP_MANAGER_ROLE incorrect assignees");
        // only emissionManager has EMISSION_ROLE
        assertTrue(CXT.hasRole(CXT.EMISSION_ROLE(), address(emissionManager)));
        assertEq(CXT.getRoleMemberCount(CXT.EMISSION_ROLE()), 1, "EMISSION_ROLE incorrect assignees");
        // only protocolCouncil has PERMIT2_REVOKER_ROLE
        assertTrue(CXT.hasRole(CXT.PERMIT2_REVOKER_ROLE(), protocolCouncil));
        assertTrue(CXT.hasRole(CXT.PERMIT2_REVOKER_ROLE(), emergencyCouncil));
        assertEq(CXT.getRoleMemberCount(CXT.PERMIT2_REVOKER_ROLE()), 2, "PERMIT2_REVOKER_ROLE incorrect assignees");
    }

    function test_InvalidDeployment() external {
        CovalentXToken token;
        vm.expectRevert(ICovalentXToken.InvalidAddress.selector);
        token = new CovalentXToken(
            address(0),
            makeAddr("emissionManager"),
            makeAddr("protocolCouncil"),
            makeAddr("emergencyCouncil")
        );
        vm.expectRevert(ICovalentXToken.InvalidAddress.selector);
        token = new CovalentXToken(
            makeAddr("migration"),
            address(0),
            makeAddr("protocolCouncil"),
            makeAddr("emergencyCouncil")
        );
        vm.expectRevert(ICovalentXToken.InvalidAddress.selector);
        token = new CovalentXToken(
            makeAddr("migration"),
            makeAddr("emissionManager"),
            address(0),
            makeAddr("emergencyCouncil")
        );
        vm.expectRevert(ICovalentXToken.InvalidAddress.selector);
        token = new CovalentXToken(
            makeAddr("migration"),
            makeAddr("emissionManager"),
            makeAddr("protocolCouncil"),
            address(0)
        );
    }

    function testRevert_UpdateMintCap(uint256 newCap, address caller) external {
        vm.assume(caller != protocolCouncil);
        vm.prank(caller);
        vm.expectRevert();
        CXT.updateMintCap(newCap);
    }

    function testRevert_Mint(address user, address to, uint256 amount) external {
        vm.assume(user != address(emissionManager));
        vm.startPrank(user);
        vm.expectRevert();
        CXT.mint(to, amount);
    }

    function test_Mint(address to, uint256 amount) external {
        skip(1e9); // delay needed for a max mint of 1B
        vm.assume(to != address(0) && amount <= 1000000000 * 10 ** 18 && to != migration);
        vm.prank(address(emissionManager));
        CXT.mint(to, amount);

        assertEq(CXT.balanceOf(to), amount);
    }

    function testRevert_Permit2Revoke(address user) external {
        vm.assume(user != protocolCouncil && user != emergencyCouncil);
        vm.startPrank(user);
        vm.expectRevert();
        CXT.updatePermit2Allowance(false);
    }

    function test_RevokePermit2Allowance(address owner) external {
        assertEq(CXT.allowance(owner, CXT.PERMIT2()), type(uint256).max);
        vm.prank(emergencyCouncil);
        vm.expectEmit(true, true, true, true);
        emit Permit2AllowanceUpdated(false);
        CXT.updatePermit2Allowance(false);
        assertFalse(CXT.permit2Enabled());
        assertEq(CXT.allowance(owner, CXT.PERMIT2()), 0);
    }

    function test_MintMaxExceeded(address to, uint256 amount, uint256 delay) external {
        vm.assume(to != address(0) && amount <= 1000000000 * 10 ** 18 && to != migration && delay < 10 * 365 days);
        skip(++delay); // avoid delay == 0

        uint256 maxMint = delay * mintPerSecondCap;
        if (amount > maxMint) {
            vm.expectRevert(abi.encodeWithSelector(ICovalentXToken.MaxMintExceeded.selector, maxMint, amount));
        }
        vm.prank(address(emissionManager));
        CXT.mint(to, amount);

        if (amount <= maxMint) assertEq(CXT.balanceOf(to), amount);
    }

    function test_Permit2Transfer() external {
        address user = makeAddr("user");
        uint256 fromPrivateKey = 0x12341234;
        address from = vm.addr(fromPrivateKey);
        uint160 defaultAmount = 10 * 10e18;
        uint48 defaultNonce = 0;
        uint48 defaultExpiration = uint48(block.timestamp + 5);

        IPermit2 permit2 = IPermit2(CXT.PERMIT2());
        vm.prank(migration);
        CXT.transfer(from, defaultAmount);
        IPermit2.PermitSingle memory permit = defaultERC20PermitAllowance(
            address(CXT),
            defaultAmount,
            defaultExpiration,
            defaultNonce
        );
        bytes memory sig = getPermitSignature(permit, fromPrivateKey, permit2.DOMAIN_SEPARATOR());

        uint256 startBalanceTo = CXT.balanceOf(user);
        permit2.permit(from, permit, sig);

        permit2.transferFrom(from, user, defaultAmount, address(CXT));
        assertEq(CXT.balanceOf(user), startBalanceTo + defaultAmount);
    }

    function test_RevertExtraAmountPermit2Transfer() external {
        address user = makeAddr("user");
        uint256 fromPrivateKey = 0x12341234;
        address from = vm.addr(fromPrivateKey);
        uint160 defaultAmount = 10 * 10e18;
        uint48 defaultNonce = 0;
        uint48 defaultExpiration = uint48(block.timestamp + 5);
        IPermit2 permit2 = IPermit2(CXT.PERMIT2());
        vm.prank(migration);
        CXT.transfer(from, defaultAmount);
        IPermit2.PermitSingle memory permit = defaultERC20PermitAllowance(
            address(CXT),
            defaultAmount,
            defaultExpiration,
            defaultNonce
        );
        bytes memory sig = getPermitSignature(permit, fromPrivateKey, permit2.DOMAIN_SEPARATOR());

        permit2.permit(from, permit, sig);

        vm.expectRevert(abi.encodeWithSelector(IPermit2.InsufficientAllowance.selector, defaultAmount));
        permit2.transferFrom(from, user, defaultAmount * 2, address(CXT));
    }

    function test_RevertPermit2DuplicateSigTransfer() external {
        address user = makeAddr("user");
        uint256 fromPrivateKey = 0x12341234;
        address from = vm.addr(fromPrivateKey);
        uint160 defaultAmount = 10 * 10e18;
        uint48 defaultNonce = 0;
        uint48 defaultExpiration = uint48(block.timestamp + 5);

        IPermit2 permit2 = IPermit2(CXT.PERMIT2());
        vm.prank(migration);
        CXT.transfer(from, defaultAmount);
        IPermit2.PermitSingle memory permit = defaultERC20PermitAllowance(
            address(CXT),
            defaultAmount,
            defaultExpiration,
            defaultNonce
        );
        bytes memory sig = getPermitSignature(permit, fromPrivateKey, permit2.DOMAIN_SEPARATOR());

        uint256 startBalanceTo = CXT.balanceOf(user);
        permit2.permit(from, permit, sig);

        permit2.transferFrom(from, user, defaultAmount, address(CXT));
        assertEq(CXT.balanceOf(user), startBalanceTo + defaultAmount);
        vm.prank(migration);
        CXT.transfer(from, defaultAmount);
        vm.expectRevert(abi.encodeWithSelector(IPermit2.InsufficientAllowance.selector, 0));
        permit2.transferFrom(from, user, defaultAmount, address(CXT));
    }

    // Permit2 helper functions

    function getPermitSignatureRaw(
        IPermit2.PermitSingle memory permit,
        uint256 privateKey,
        bytes32 domainSeparator
    ) internal pure returns (uint8 v, bytes32 r, bytes32 s) {
        bytes32 permitHash = keccak256(abi.encode(_PERMIT_DETAILS_TYPEHASH, permit.details));

        bytes32 msgHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(abi.encode(_PERMIT_SINGLE_TYPEHASH, permitHash, permit.spender, permit.sigDeadline))
            )
        );

        (v, r, s) = vm.sign(privateKey, msgHash);
    }

    function getPermitSignature(
        IPermit2.PermitSingle memory permit,
        uint256 privateKey,
        bytes32 domainSeparator
    ) internal pure returns (bytes memory sig) {
        (uint8 v, bytes32 r, bytes32 s) = getPermitSignatureRaw(permit, privateKey, domainSeparator);
        return bytes.concat(r, s, bytes1(v));
    }

    function defaultERC20PermitAllowance(
        address token0,
        uint160 amount,
        uint48 expiration,
        uint48 nonce
    ) internal view returns (IPermit2.PermitSingle memory) {
        IPermit2.PermitDetails memory details = IPermit2.PermitDetails({
            token: token0,
            amount: amount,
            expiration: expiration,
            nonce: nonce
        });
        return IPermit2.PermitSingle({details: details, spender: address(this), sigDeadline: block.timestamp + 100});
    }
}

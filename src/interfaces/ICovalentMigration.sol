// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/// @title Covalent Token Migration Contract
/// @author Covalent
/// @dev The contract allows governance/owner to distribute tokens.
interface ICovalentMigration {
    /// @notice This function allows owner/governance to set CXT token address.
    /// @param _cxt Address of deployed CXT token
    function setToken(address _cxt) external;

    /// @notice This function allows owner/governance to distribute CXT tokens.
    /// @notice `recipients` and `amounts` must have the same length.
    /// @param recipients Addresses of recipients
    /// @param amounts Amounts of tokens to be distributed
    function batchDistribute(address[] calldata recipients, uint256[] calldata amounts) external;

    function cxt() external view returns (IERC20);
}

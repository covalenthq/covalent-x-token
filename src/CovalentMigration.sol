// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable2StepUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";
import {ICovalentMigration} from "src/interfaces/ICovalentMigration.sol";

/// @title Covalent Network Token initial Migration contract
/// @author
contract CovalentMigration is Ownable2StepUpgradeable, ICovalentMigration {
    using SafeERC20 for IERC20;

    IERC20 public cxt;

    constructor() {
        _disableInitializers();
    }

    function initialize() external initializer {
        __Ownable_init();
    }

    /// @inheritdoc ICovalentMigration
    function setToken(address _cxt) external onlyOwner {
        require(_cxt != address(0), "CovalentMigration: address cannot be zero");
        cxt = IERC20(_cxt);
    }

    /// @inheritdoc ICovalentMigration
    function batchDistribute(address[] calldata recipients, uint256[] calldata amounts) external onlyOwner {
        require(recipients.length == amounts.length, "CovalentMigration: recipients and amounts length mismatch");
        for (uint256 i = 0; i < recipients.length; i++) {
            cxt.safeTransfer(recipients[i], amounts[i]);
        }
    }
}

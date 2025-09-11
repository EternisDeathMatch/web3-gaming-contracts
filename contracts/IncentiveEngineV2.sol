// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IncentiveEngine.sol";

/**
 * @title IncentiveEngineV2
 * @notice Extension of IncentiveEngine with convenience admin management helpers.
 *         Safe for upgrade because storage layout is unchanged.
 */
contract IncentiveEngineV2 is IncentiveEngine {
    /// @notice Add a new admin (must be DEFAULT_ADMIN_ROLE)
    function addAdmin(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(ADMIN_ROLE, account);
    }

    /// @notice Remove an admin (must be DEFAULT_ADMIN_ROLE)
    function removeAdmin(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(ADMIN_ROLE, account);
    }

    /// @notice Check if an address has ADMIN_ROLE
    function isAdmin(address account) external view returns (bool) {
        return hasRole(ADMIN_ROLE, account);
    }

    function version() external pure override returns (string memory) {
        return "IncentiveEngine v2 (admin helpers)";
    }
}

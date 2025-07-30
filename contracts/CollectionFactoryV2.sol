// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./CollectionFactory.sol";

contract CollectionFactoryV2 is CollectionFactory {
    // New state variable must be added AFTER all V1 state!
    string public version;

    // Optionally, a versioned initializer if you need to set `version` at upgrade time
    function initializeV2(
        string calldata _version
    ) external reinitializer(2) onlyRole(ADMIN_ROLE) {
        version = _version;
    }

    // Update access control to match new base contract
    function setVersion(
        string calldata _version
    ) external onlyRole(ADMIN_ROLE) {
        version = _version;
    }
}
// version() view returns (string)
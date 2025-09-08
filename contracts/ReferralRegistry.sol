// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title ReferralRegistry
 * @notice Simple bind-once referral mapping: user -> referrer
 */
contract ReferralRegistry is Initializable, AccessControlUpgradeable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    mapping(address => address) public referrerOf;

    event ReferrerBound(address indexed user, address indexed referrer);

    function initialize(address admin) public initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
    }

    /// @notice Bind msg.sender to a referrer (one-time). Blocks self and short cycles.
    function bindReferrer(address referrer) external {
        require(referrer != address(0), "ref=0");
        require(referrer != msg.sender, "self");
        require(referrerOf[msg.sender] == address(0), "already");
        require(referrerOf[referrer] != msg.sender, "cycle");
        referrerOf[msg.sender] = referrer;
        emit ReferrerBound(msg.sender, referrer);
    }
}

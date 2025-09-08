// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

interface IReferralRegistry {
    function referrerOf(address user) external view returns (address);
}

/**
 * @title IncentiveEngine
 * @notice Accepts a precomputed POOL (native or ERC20) and splits it between:
 *         buyer cashback, L1 referrer, L2 referrer, and treasury (dust/unassigned).
 *         Uses pull-payments (claimables). Upgradeable (UUPS).
 *
 * @dev Scope is a free bytes32 (suggest: bytes32(uint256(uint160(collectionAddr))))
 *      Option B: preferred payout wallet routing for future accruals.
 */
contract IncentiveEngine is
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    // -------- Roles --------
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // -------- Types --------
    struct Split {
        uint16 buyerCashbackBps; // of POOL (0..10000)
        uint16 l1ReferrerBps; // of POOL
        uint16 l2ReferrerBps; // of POOL
        address payoutToken; // address(0) => native; else ERC20 token address
        address treasury; // receives remainder & dust
        bool recycleMissingToBuyer; // optional: missing L1/L2 → buyer
        bool recycleMissingToSeller; // optional: missing L1/L2 → seller
        bool active;
    }

    // -------- State --------
    IReferralRegistry public registry;

    // scope => split config
    mapping(bytes32 => Split) public splits;

    // user => token => claimable amount
    mapping(address => mapping(address => uint256)) public claimable;

    // Option B: preferred payout routing (future accruals go here)
    mapping(address => address) public payoutOf; // user -> preferred payout wallet (0 = self)

    // -------- Events --------
    event RegistrySet(address indexed registry);
    event SplitSet(
        bytes32 indexed scope,
        uint16 buyerCashbackBps,
        uint16 l1ReferrerBps,
        uint16 l2ReferrerBps,
        address payoutToken,
        address treasury,
        bool recycleMissingToBuyer,
        bool recycleMissingToSeller,
        bool active
    );
    event PoolSettled(
        bytes32 indexed scope,
        address indexed buyer,
        address l1,
        address l2,
        address token,
        uint256 pool,
        uint256 toBuyer,
        uint256 toL1,
        uint256 toL2,
        uint256 toTreasury
    );
    event Claimed(address indexed user, address indexed token, uint256 amount);
    event ClaimedTo(
        address indexed user,
        address indexed token,
        address indexed to,
        uint256 amount
    );
    event PayoutAddressSet(address indexed user, address indexed newPayout);

    // -------- Init / Upgrade --------
    function initialize(address admin, address _registry) public initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);

        registry = IReferralRegistry(_registry);
        emit RegistrySet(_registry);
    }

    function _authorizeUpgrade(
        address
    ) internal override onlyRole(ADMIN_ROLE) {}

    // -------- Admin --------
    function setRegistry(address _registry) external onlyRole(ADMIN_ROLE) {
        require(_registry != address(0), "reg=0");
        registry = IReferralRegistry(_registry);
        emit RegistrySet(_registry);
    }

    function setSplit(
        bytes32 scope,
        Split calldata s
    ) external onlyRole(ADMIN_ROLE) {
        require(s.treasury != address(0), "treasury=0");
        require(
            uint256(s.buyerCashbackBps) + s.l1ReferrerBps + s.l2ReferrerBps <=
                10_000,
            "bps>100%"
        );
        splits[scope] = s;
        emit SplitSet(
            scope,
            s.buyerCashbackBps,
            s.l1ReferrerBps,
            s.l2ReferrerBps,
            s.payoutToken,
            s.treasury,
            s.recycleMissingToBuyer,
            s.recycleMissingToSeller,
            s.active
        );
    }

    // -------- User payout preferences (Option B) --------

    /// @notice Set preferred payout wallet for future accruals.
    function setPayoutAddress(address newPayout) external {
        require(newPayout != address(0), "payout=0");
        payoutOf[msg.sender] = newPayout;
        emit PayoutAddressSet(msg.sender, newPayout);
    }

    function _beneficiary(address a) internal view returns (address) {
        address p = payoutOf[a];
        return p == address(0) ? a : p;
    }

    // -------- Settlement (entrypoints for marketplace / token-sale) --------

    /// @notice Settle a native-coin POOL. `msg.value` must equal pool amount.
    function settleNative(
        bytes32 scope,
        address buyer,
        address seller
    ) external payable nonReentrant {
        Split memory s = splits[scope];
        require(s.active && s.payoutToken == address(0), "native disabled");
        _settle(scope, buyer, seller, address(0), msg.value, s);
    }

    /// @notice Settle an ERC20 POOL. Marketplace must have approved & will transferFrom here.
    function settleERC20(
        bytes32 scope,
        address buyer,
        address seller,
        uint256 poolAmount
    ) external nonReentrant {
        Split memory s = splits[scope];
        require(s.active && s.payoutToken != address(0), "erc20 disabled");

        // Pull tokens from caller → engine (caller should be the marketplace)
        require(
            IERC20(s.payoutToken).transferFrom(
                msg.sender,
                address(this),
                poolAmount
            ),
            "transferFrom failed"
        );

        _settle(scope, buyer, seller, s.payoutToken, poolAmount, s);
    }

    // -------- Claims --------

    /// @notice Claim accumulated rewards in native coin or ERC20 to msg.sender.
    function claim(address token) external nonReentrant {
        uint256 amt = claimable[msg.sender][token];
        require(amt > 0, "nothing");
        claimable[msg.sender][token] = 0;

        if (token == address(0)) {
            (bool ok, ) = payable(msg.sender).call{value: amt}("");
            require(ok, "native xfer");
        } else {
            require(IERC20(token).transfer(msg.sender, amt), "erc20 xfer");
        }

        emit Claimed(msg.sender, token, amt);
    }

    /// @notice Withdraw to a specific address (nice UX).
    function claimTo(address token, address to) external nonReentrant {
        require(to != address(0), "to=0");

        uint256 amt = claimable[msg.sender][token];
        require(amt > 0, "nothing");
        claimable[msg.sender][token] = 0;

        if (token == address(0)) {
            (bool ok, ) = payable(to).call{value: amt}("");
            require(ok, "native xfer");
        } else {
            require(IERC20(token).transfer(to, amt), "erc20 xfer");
        }

        emit ClaimedTo(msg.sender, token, to, amt);
    }

    /// @notice Batch-migrate existing balances to your payout wallet (for multiple tokens).
    function migrateAll(address[] calldata tokens) external nonReentrant {
        address to = payoutOf[msg.sender];
        require(to != address(0), "no payout set");

        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 amt = claimable[msg.sender][tokens[i]];
            if (amt > 0) {
                claimable[msg.sender][tokens[i]] = 0;
                claimable[to][tokens[i]] += amt;
            }
        }
    }

    // -------- Internal --------
    function _settle(
        bytes32 scope,
        address buyer,
        address seller,
        address token,
        uint256 pool,
        Split memory s
    ) internal {
        address l1 = registry.referrerOf(buyer);
        address l2 = l1 != address(0) ? registry.referrerOf(l1) : address(0);

        // Preferred payout routing (Option B)
        address bBuyer = _beneficiary(buyer);
        address bL1 = l1 == address(0) ? address(0) : _beneficiary(l1);
        address bL2 = l2 == address(0) ? address(0) : _beneficiary(l2);
        address bSeller = seller == address(0)
            ? address(0)
            : _beneficiary(seller);

        uint256 toBuyer = (pool * s.buyerCashbackBps) / 10_000;
        uint256 toL1 = l1 != address(0) ? (pool * s.l1ReferrerBps) / 10_000 : 0;
        uint256 toL2 = l2 != address(0) ? (pool * s.l2ReferrerBps) / 10_000 : 0;

        // Recycle missing referral shares
        if (s.recycleMissingToBuyer) {
            if (toL1 == 0 && s.l1ReferrerBps > 0)
                toBuyer += (pool * s.l1ReferrerBps) / 10_000;
            if (toL2 == 0 && s.l2ReferrerBps > 0)
                toBuyer += (pool * s.l2ReferrerBps) / 10_000;
        } else if (s.recycleMissingToSeller && bSeller != address(0)) {
            if (toL1 == 0 && s.l1ReferrerBps > 0)
                claimable[bSeller][token] += (pool * s.l1ReferrerBps) / 10_000;
            if (toL2 == 0 && s.l2ReferrerBps > 0)
                claimable[bSeller][token] += (pool * s.l2ReferrerBps) / 10_000;
        }

        uint256 distributed = toBuyer + toL1 + toL2;

        // Include recycled-to-seller amounts in distributed math
        if (
            !s.recycleMissingToBuyer &&
            s.recycleMissingToSeller &&
            bSeller != address(0)
        ) {
            uint256 recycled = ((
                l1 == address(0) ? (pool * s.l1ReferrerBps) / 10_000 : 0
            ) + (l2 == address(0) ? (pool * s.l2ReferrerBps) / 10_000 : 0));
            distributed += recycled;
        }

        uint256 toTreasury = pool - distributed;

        if (toBuyer > 0) claimable[bBuyer][token] += toBuyer;
        if (toL1 > 0) claimable[bL1][token] += toL1;
        if (toL2 > 0) claimable[bL2][token] += toL2;
        if (toTreasury > 0) claimable[s.treasury][token] += toTreasury;

        emit PoolSettled(
            scope,
            buyer,
            l1,
            l2,
            token,
            pool,
            toBuyer,
            toL1,
            toL2,
            toTreasury
        );
    }

    // -------- View helpers --------
    function claimableOf(
        address user,
        address token
    ) external view returns (uint256) {
        return claimable[user][token];
    }

    function version() external pure returns (string memory) {
        return "IncentiveEngine v1 (pool splitter + payout routing)";
    }
}

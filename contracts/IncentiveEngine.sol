// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

interface IReferralRegistry {
    function referrerOf(address user) external view returns (address);
}

/**
 * @title IncentiveEngine (flex-depth, extensible)
 * @notice Splits a POOL (native or ERC20) among:
 *         - buyer cashback (if allowed)
 *         - N referral levels
 *         - seller (optional recycled)
 *         - treasury
 *         Uses pull-payments (claimables). Upgradeable (UUPS).
 *
 * Key overridable hooks:
 *  - settleNative / settleERC20 / claim / claimTo / setSplit / setReferrerBps / setRegistry (external virtual)
 *  - _settle / _beneficiary / _referrerOf / _allowCashback / _pullERC20 / _payoutNative / _payoutERC20 (internal virtual)
 *  - _beforeSettle / _afterSettle / _onAccrual (internal virtual hooks)
 */
contract IncentiveEngine is
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    struct Split {
        uint16 buyerCashbackBps; // basis points (0..10000)
        address payoutToken; // address(0) = native; else ERC20 address
        address treasury;
        bool recycleMissingToBuyer;
        bool recycleMissingToSeller;
        bool active;
    }

    IReferralRegistry public registry;

    // scope => base split config
    mapping(bytes32 => Split) public splits;

    // scope => per-level referral bps [L1, L2, L3, ...]
    mapping(bytes32 => uint16[]) public referrerBps;

    // user => token => claimable balance
    mapping(address => mapping(address => uint256)) public claimable;

    // optional preferred payout wallet
    mapping(address => address) public payoutOf;

    // -------- Events --------
    event RegistrySet(address indexed registry);
    event SplitSet(
        bytes32 indexed scope,
        uint16 buyerCashbackBps,
        address payoutToken,
        address treasury,
        bool recycleMissingToBuyer,
        bool recycleMissingToSeller,
        bool active
    );
    event ReferrerBpsSet(bytes32 indexed scope, uint16[] bps);

    event PoolSettled(
        bytes32 indexed scope,
        address indexed buyer,
        address indexed seller,
        address token,
        uint256 pool,
        uint256 toBuyer,
        uint256 toReferrers,
        uint256 toSellerRecycled,
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

    // -------- Init --------
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

    // -------- Admin (overridable) --------
    function setRegistry(
        address _registry
    ) external virtual onlyRole(ADMIN_ROLE) {
        require(_registry != address(0), "reg=0");
        registry = IReferralRegistry(_registry);
        emit RegistrySet(_registry);
    }

    function setSplit(
        bytes32 scope,
        Split calldata s
    ) external virtual onlyRole(ADMIN_ROLE) {
        require(s.treasury != address(0), "treasury=0");
        splits[scope] = s;
        emit SplitSet(
            scope,
            s.buyerCashbackBps,
            s.payoutToken,
            s.treasury,
            s.recycleMissingToBuyer,
            s.recycleMissingToSeller,
            s.active
        );
    }

    function setReferrerBps(
        bytes32 scope,
        uint16[] calldata bps
    ) external virtual onlyRole(ADMIN_ROLE) {
        Split memory s = splits[scope];
        require(s.treasury != address(0), "set split first");

        uint256 sum = s.buyerCashbackBps;
        for (uint256 i = 0; i < bps.length; i++) sum += bps[i];
        require(sum <= 10_000, "bps>100%");

        referrerBps[scope] = bps;
        emit ReferrerBpsSet(scope, bps);
    }

    // -------- User prefs --------
    function setPayoutAddress(address newPayout) external {
        require(newPayout != address(0), "payout=0");
        payoutOf[msg.sender] = newPayout;
        emit PayoutAddressSet(msg.sender, newPayout);
    }

    // -------- Internal helpers (overridable) --------

    /// @dev Override to route accruals to a different wallet (custodial, smart account, etc.)
    function _beneficiary(address a) internal view virtual returns (address) {
        address p = payoutOf[a];
        return p == address(0) ? a : p;
    }

    /// @dev Override to plug custom referral source (codes, signatures, multiple registries).
    function _referrerOf(address user) internal view virtual returns (address) {
        return registry.referrerOf(user);
    }

    /// @dev Override to change cashback eligibility (e.g., promo weeks, KYC gates, etc.)
    function _allowCashback(
        bytes32 /*scope*/,
        address buyer
    ) internal view virtual returns (bool) {
        return _referrerOf(buyer) != address(0);
    }

    /// @dev Hook before settlement. Default no-op.
    function _beforeSettle(
        bytes32 /*scope*/,
        address /*buyer*/,
        address /*seller*/,
        address /*token*/,
        uint256 /*pool*/,
        Split memory /*s*/
    ) internal virtual {}

    /// @dev Hook after settlement. Default no-op.
    function _afterSettle(
        bytes32 /*scope*/,
        address /*buyer*/,
        address /*seller*/,
        address /*token*/,
        uint256 /*pool*/,
        uint256 /*toBuyer*/,
        uint256 /*toReferrers*/,
        uint256 /*toSellerRecycled*/,
        uint256 /*toTreasury*/
    ) internal virtual {}

    /// @dev Hook on accrual writes. Use for analytics/mirroring. Default no-op.
    function _onAccrual(
        address /*recipient*/,
        address /*token*/,
        uint256 /*amount*/,
        bytes32 /*reason*/
    ) internal virtual {}

    /// @dev Pull ERC20 tokens; override for fee-on-transfer support if needed.
    function _pullERC20(
        address token,
        address from,
        uint256 amount
    ) internal virtual returns (uint256 received) {
        uint256 beforeBal = IERC20(token).balanceOf(address(this));
        require(
            IERC20(token).transferFrom(from, address(this), amount),
            "transferFrom failed"
        );
        uint256 afterBal = IERC20(token).balanceOf(address(this));
        return afterBal - beforeBal; // equals amount for standard tokens
    }

    /// @dev Payout helpers used by claim/claimTo; override to add fees/throttling/bridging.
    function _payoutNative(address to, uint256 amt) internal virtual {
        (bool ok, ) = payable(to).call{value: amt}("");
        require(ok, "native xfer");
    }

    function _payoutERC20(
        address token,
        address to,
        uint256 amt
    ) internal virtual {
        require(IERC20(token).transfer(to, amt), "erc20 xfer");
    }

    // -------- Settlement entry points (overridable) --------

    function settleNative(
        bytes32 scope,
        address buyer,
        address seller
    ) external payable virtual nonReentrant {
        Split memory s = splits[scope];
        require(s.active && s.payoutToken == address(0), "native disabled");
        _settle(scope, buyer, seller, address(0), msg.value, s);
    }

    function settleERC20(
        bytes32 scope,
        address buyer,
        address seller,
        uint256 poolAmount
    ) external virtual nonReentrant {
        Split memory s = splits[scope];
        require(s.active && s.payoutToken != address(0), "erc20 disabled");
        // Pull and compute actual received (safe for fee-on-transfer tokens)
        uint256 received = _pullERC20(s.payoutToken, msg.sender, poolAmount);
        _settle(scope, buyer, seller, s.payoutToken, received, s);
    }

    // -------- Claims (overridable) --------

    function claim(address token) external virtual nonReentrant {
        uint256 amt = claimable[msg.sender][token];
        require(amt > 0, "nothing");
        claimable[msg.sender][token] = 0;

        if (token == address(0)) {
            _payoutNative(msg.sender, amt);
        } else {
            _payoutERC20(token, msg.sender, amt);
        }
        emit Claimed(msg.sender, token, amt);
    }

    function claimTo(address token, address to) external virtual nonReentrant {
        require(to != address(0), "to=0");
        uint256 amt = claimable[msg.sender][token];
        require(amt > 0, "nothing");
        claimable[msg.sender][token] = 0;

        if (token == address(0)) {
            _payoutNative(to, amt);
        } else {
            _payoutERC20(token, to, amt);
        }
        emit ClaimedTo(msg.sender, token, to, amt);
    }

    // -------- Core settlement (overridable) --------

    function _settle(
        bytes32 scope,
        address buyer,
        address seller,
        address token,
        uint256 pool,
        Split memory s
    ) internal virtual {
        _beforeSettle(scope, buyer, seller, token, pool, s);

        uint16[] memory levels = referrerBps[scope];
        require(levels.length > 0, "no bps set");

        // Cashback eligibility (default: must be referred)
        bool allowCashback = _allowCashback(scope, buyer);

        // L1 referrer (chain traversal starts here)
        address l1 = _referrerOf(buyer);

        address bBuyer = _beneficiary(buyer);
        address bSeller = seller == address(0)
            ? address(0)
            : _beneficiary(seller);

        // Base cashback only if buyer is eligible
        uint256 toBuyer = allowCashback
            ? (pool * s.buyerCashbackBps) / 10_000
            : 0;
        uint256 distributed = toBuyer;
        uint256 refTotal = 0;
        uint256 toSellerRecycled = 0;

        // Walk referral chain starting from L1
        address current = l1;
        for (uint256 i = 0; i < levels.length; i++) {
            uint256 share = (pool * levels[i]) / 10_000;

            if (current == address(0)) {
                // Missing level
                if (share > 0) {
                    if (s.recycleMissingToBuyer && allowCashback) {
                        toBuyer += share;
                        distributed += share;
                    } else if (
                        s.recycleMissingToSeller && bSeller != address(0)
                    ) {
                        claimable[bSeller][token] += share;
                        distributed += share;
                        toSellerRecycled += share;
                        _onAccrual(
                            bSeller,
                            token,
                            share,
                            keccak256("RECYCLE_TO_SELLER")
                        );
                    }
                    // else: falls through to treasury via (pool - distributed)
                }
            } else {
                // Pay this referrer
                address beneficiary = _beneficiary(current);
                claimable[beneficiary][token] += share;
                refTotal += share;
                distributed += share;
                _onAccrual(
                    beneficiary,
                    token,
                    share,
                    keccak256(abi.encodePacked("REFERRER_L", i + 1))
                );

                // advance to next level
                current = _referrerOf(current);
            }
        }

        uint256 toTreasury = pool - distributed;

        if (toBuyer > 0) {
            claimable[bBuyer][token] += toBuyer;
            _onAccrual(bBuyer, token, toBuyer, keccak256("BUYER_CASHBACK"));
        }
        if (toTreasury > 0) {
            claimable[s.treasury][token] += toTreasury;
            _onAccrual(s.treasury, token, toTreasury, keccak256("TREASURY"));
        }

        emit PoolSettled(
            scope,
            buyer,
            seller,
            token,
            pool,
            toBuyer,
            refTotal,
            toSellerRecycled,
            toTreasury
        );

        _afterSettle(
            scope,
            buyer,
            seller,
            token,
            pool,
            toBuyer,
            refTotal,
            toSellerRecycled,
            toTreasury
        );
    }

    // -------- Views --------
    function claimableOf(
        address user,
        address token
    ) external view returns (uint256) {
        return claimable[user][token];
    }

    function version() external pure virtual returns (string memory) {
        return "IncentiveEngine v1-ext (overridable)";
    }
}

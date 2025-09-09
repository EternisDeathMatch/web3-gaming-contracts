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
 * @title IncentiveEngine (flex-depth only)
 * @notice Splits a POOL (native or ERC20) among:
 *         - buyer cashback
 *         - N referral levels
 *         - treasury
 *         Uses pull-payments (claimables). Upgradeable (UUPS).
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
        address payoutToken; // address(0) = native; else ERC20
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
    ) external onlyRole(ADMIN_ROLE) {
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

    function _beneficiary(address a) internal view returns (address) {
        address p = payoutOf[a];
        return p == address(0) ? a : p;
    }

    // -------- Settlement --------
    function settleNative(
        bytes32 scope,
        address buyer,
        address seller
    ) external payable nonReentrant {
        Split memory s = splits[scope];
        require(s.active && s.payoutToken == address(0), "native disabled");
        _settle(scope, buyer, seller, address(0), msg.value, s);
    }

    function settleERC20(
        bytes32 scope,
        address buyer,
        address seller,
        uint256 poolAmount
    ) external nonReentrant {
        Split memory s = splits[scope];
        require(s.active && s.payoutToken != address(0), "erc20 disabled");
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

    // -------- Internal --------
    function _settle(
        bytes32 scope,
        address buyer,
        address seller,
        address token,
        uint256 pool,
        Split memory s
    ) internal {
        uint16[] memory levels = referrerBps[scope];
        require(levels.length > 0, "no bps set");

        address bBuyer = _beneficiary(buyer);
        address bSeller = seller == address(0)
            ? address(0)
            : _beneficiary(seller);

        uint256 toBuyer = (pool * s.buyerCashbackBps) / 10_000;
        uint256 distributed = toBuyer;
        uint256 refTotal = 0;
        uint256 toSellerRecycled = 0; // track recycled shares

        address current = buyer;
        for (uint256 i = 0; i < levels.length; i++) {
            current = registry.referrerOf(current);
            uint256 bps = levels[i];
            uint256 share = (pool * bps) / 10_000;

            if (current == address(0)) {
                if (share > 0) {
                    if (s.recycleMissingToBuyer) {
                        toBuyer += share;
                        distributed += share;
                    } else if (
                        s.recycleMissingToSeller && bSeller != address(0)
                    ) {
                        claimable[bSeller][token] += share;
                        distributed += share;
                        toSellerRecycled += share; // NEW
                    }
                }
                continue;
            }

            claimable[_beneficiary(current)][token] += share;
            refTotal += share;
            distributed += share;
        }

        uint256 toTreasury = pool - distributed;

        if (toBuyer > 0) claimable[bBuyer][token] += toBuyer;
        if (toTreasury > 0) claimable[s.treasury][token] += toTreasury;

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
    }

    // -------- Views --------
    function claimableOf(
        address user,
        address token
    ) external view returns (uint256) {
        return claimable[user][token];
    }

    function version() external pure returns (string memory) {
        return "IncentiveEngine v1 (flex-depth + seller in events)";
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
 * Rebased from your deployed V1 to allow modifying buyItem without inheritance.
 * - Storage order up to listingIndex is identical to V1
 * - New V3 state is appended at the end (safe for upgradeable proxy)
 */

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/common/ERC2981Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

// Interfaces used in logic
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC2981} from "@openzeppelin/contracts/interfaces/IERC2981.sol";

/* ---------- External Incentive Engine Interface ---------- */
interface IIncentiveEngine {
    function settleNative(
        bytes32 scope,
        address buyer,
        address seller
    ) external payable;
    function settleERC20(
        bytes32 scope,
        address buyer,
        address seller,
        uint256 poolAmount
    ) external;
}

/**
 * @title GameMarketplaceV3
 * @dev Upgrade implementation that adds referral incentive pool forwarding.
 *      This contract *does not inherit V1/V2* to allow changing buyItem while
 *      keeping the same storage layout. Copy of V1 + appended V3 state & logic.
 */
contract GameMarketplaceV3 is
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable,
    AccessControlUpgradeable
{
    /* ========= V1 (unchanged) ========= */

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    struct Listing {
        address seller;
        address nftContract;
        uint256 tokenId;
        address paymentToken; // address(0) for native token
        uint256 price;
        uint256 expiresAt;
        bool active;
    }

    // Platform fee in basis points (100 = 1%)
    uint256 public platformFeeBps; // 2.5%
    address public feeRecipient;

    // Mapping from listing ID to listing details
    mapping(bytes32 => Listing) public listings;
    // Active listing per NFT
    mapping(address => mapping(uint256 => bytes32)) public activeListing;
    // Supported payment tokens
    mapping(address => bool) public supportedTokens;

    // Index of all active listing IDs
    bytes32[] private activeListingIds;
    // Mapping to track listing existence in activeListingIds
    mapping(bytes32 => uint256) private listingIndex;

    // Events (V1)
    event ItemListed(
        bytes32 indexed listingId,
        address indexed seller,
        address indexed nftContract,
        uint256 tokenId,
        address paymentToken,
        uint256 price,
        uint256 expiresAt
    );
    event ItemSold(
        bytes32 indexed listingId,
        address indexed buyer,
        address indexed seller,
        uint256 price,
        uint256 platformFee,
        uint256 royaltyFee
    );
    event ListingCancelled(bytes32 indexed listingId);
    event PlatformFeeUpdated(uint256 newFeeBps);

    function initialize(address _feeRecipient) public initializer {
        __ReentrancyGuard_init();
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        platformFeeBps = 250;
        feeRecipient = _feeRecipient;
        supportedTokens[address(0)] = true;

        // Grant ADMIN_ROLE to deployer (msg.sender)
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    function addAdmin(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(ADMIN_ROLE, account);
    }

    function removeAdmin(
        address account
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(ADMIN_ROLE, account);
    }

    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender), "Not admin");
        _;
    }

    function _authorizeUpgrade(address) internal override onlyAdmin {}

    /// @dev Internal helper for both single‐ and batch‐listing
    function _createListing(
        address nftContract,
        uint256 tokenId,
        address paymentToken,
        uint256 price,
        uint256 duration
    ) internal {
        require(price > 0, "Price must be > 0");
        require(duration > 0, "Duration must be > 0");
        require(supportedTokens[paymentToken], "Payment not supported");
        require(
            IERC721(nftContract).ownerOf(tokenId) == msg.sender,
            "Not owner"
        );
        require(
            IERC721(nftContract).isApprovedForAll(msg.sender, address(this)) ||
                IERC721(nftContract).getApproved(tokenId) == address(this),
            "Not approved"
        );

        bytes32 existing = activeListing[nftContract][tokenId];
        require(
            existing == bytes32(0) || !listings[existing].active,
            "Already listed"
        );

        bytes32 listingId = keccak256(
            abi.encodePacked(msg.sender, nftContract, tokenId, block.timestamp)
        );
        uint256 expiresAt = block.timestamp + duration;

        listings[listingId] = Listing(
            msg.sender,
            nftContract,
            tokenId,
            paymentToken,
            price,
            expiresAt,
            true
        );
        activeListing[nftContract][tokenId] = listingId;

        // Index active listing
        listingIndex[listingId] = activeListingIds.length;
        activeListingIds.push(listingId);

        emit ItemListed(
            listingId,
            msg.sender,
            nftContract,
            tokenId,
            paymentToken,
            price,
            expiresAt
        );
    }

    /// @notice Batch list multiple NFTs at once
    function batchListItems(
        address nftContract,
        uint256[] calldata tokenIds,
        address paymentToken,
        uint256[] calldata prices,
        uint256 duration
    ) external virtual whenNotPaused nonReentrant {
        require(
            tokenIds.length == prices.length,
            "IDs and prices length mismatch"
        );
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _createListing(
                nftContract,
                tokenIds[i],
                paymentToken,
                prices[i],
                duration
            );
        }
    }

    function listItem(
        address nftContract,
        uint256 tokenId,
        address paymentToken,
        uint256 price,
        uint256 duration
    ) external virtual whenNotPaused nonReentrant {
        _createListing(nftContract, tokenId, paymentToken, price, duration);
    }

    /// @notice Cancel an active listing
    function cancelListing(bytes32 listingId) external virtual nonReentrant {
        _cancelListingInternal(listingId, msg.sender);
    }

    function _cancelListingInternal(
        bytes32 listingId,
        address sender
    ) internal {
        Listing storage l = listings[listingId];
        require(l.active, "Not active");
        require(sender == l.seller, "Not seller");
        _removeListing(listingId);
        emit ListingCancelled(listingId);
    }

    /// @notice Batch cancel multiple active listings
    function batchCancelListings(
        address nftContract,
        uint256[] calldata tokenIds
    ) external virtual nonReentrant {
        require(tokenIds.length > 0, "No tokenIds provided");
        for (uint256 i = 0; i < tokenIds.length; i++) {
            bytes32 listingId = activeListing[nftContract][tokenIds[i]];
            require(listingId != bytes32(0), "Listing not found");
            _cancelListingInternal(listingId, msg.sender);
        }
    }

    /// @dev Internal removal of listing from active index
    function _removeListing(bytes32 listingId) internal {
        Listing storage l = listings[listingId];
        l.active = false;
        delete activeListing[l.nftContract][l.tokenId];

        uint256 idx = listingIndex[listingId];
        bytes32 lastId = activeListingIds[activeListingIds.length - 1];
        activeListingIds[idx] = lastId;
        listingIndex[lastId] = idx;
        activeListingIds.pop();
        delete listingIndex[listingId];
    }

    /// @notice Get total number of active listings
    function getTotalActiveListings() external view returns (uint256) {
        return activeListingIds.length;
    }

    /// @notice Get a paginated list of active listing IDs
    function getActiveListings(
        uint256 offset,
        uint256 limit
    ) external view returns (bytes32[] memory) {
        uint256 total = activeListingIds.length;

        // clamp offset to [0, total]
        uint256 start = offset > total ? total : offset;

        // clamp end to [start, total]
        uint256 end = start + limit;
        if (end > total) end = total;

        uint256 len = end - start;
        bytes32[] memory page = new bytes32[](len);

        for (uint256 i = 0; i < len; i++) {
            page[i] = activeListingIds[start + i];
        }
        return page;
    }

    /// @notice Get all listings for a given NFT contract
    function getListingsByNFTContract(
        address nftContract
    ) external view returns (bytes32[] memory) {
        uint256 count;
        for (uint256 i = 0; i < activeListingIds.length; i++) {
            if (listings[activeListingIds[i]].nftContract == nftContract)
                count++;
        }
        bytes32[] memory result = new bytes32[](count);
        uint256 idx;
        for (uint256 i = 0; i < activeListingIds.length; i++) {
            bytes32 id = activeListingIds[i];
            if (listings[id].nftContract == nftContract) {
                result[idx++] = id;
            }
        }
        return result;
    }

    /// @notice Return listing details
    function getListing(
        bytes32 listingId
    ) external view returns (Listing memory) {
        return listings[listingId];
    }

    /// @notice Check listing validity
    function isListingValid(bytes32 listingId) external view returns (bool) {
        Listing memory l = listings[listingId];
        return
            l.active &&
            block.timestamp <= l.expiresAt &&
            IERC721(l.nftContract).ownerOf(l.tokenId) == l.seller;
    }

    /// @notice Update platform fee
    function updatePlatformFee(uint256 newFeeBps) external virtual onlyAdmin {
        require(newFeeBps <= 1000, "Max 10% fee");
        platformFeeBps = newFeeBps;
        emit PlatformFeeUpdated(newFeeBps);
    }

    /// @notice Update fee recipient
    function updateFeeRecipient(
        address newRecipient
    ) external virtual onlyAdmin {
        require(newRecipient != address(0), "Invalid recipient");
        feeRecipient = newRecipient;
    }

    function addSupportedToken(address token) external virtual onlyAdmin {
        supportedTokens[token] = true;
    }

    function removeSupportedToken(address token) external virtual onlyAdmin {
        require(token != address(0), "Cannot remove native token support");
        supportedTokens[token] = false;
    }

    function pause() external virtual onlyAdmin {
        _pause();
    }
    function unpause() external virtual onlyAdmin {
        _unpause();
    }

    /* ========= V3 (appended) ========= */

    /// @dev Address of IncentiveEngine contract that splits referral rewards.
    address public incentiveEngine;

    /// @dev Per-collection pool (in bps of price) to forward to the engine.
    mapping(address => uint16) public poolBps;

    // V3 events
    event IncentiveEngineSet(address engine);
    event PoolBpsSet(address indexed collection, uint16 bps);
    event IncentivePoolForwarded(
        bytes32 indexed scope,
        address indexed buyer,
        address indexed seller,
        address collection,
        uint256 amount
    );

    // V3 admin
    function setIncentiveEngine(address _engine) external onlyAdmin {
        require(_engine != address(0), "engine=0");
        incentiveEngine = _engine;
        emit IncentiveEngineSet(_engine);
    }

    function setPoolBps(address collection, uint16 bps) external onlyAdmin {
        require(bps <= 10_000, "bps>100%");
        poolBps[collection] = bps;
        emit PoolBpsSet(collection, bps);
    }

    // Helper to derive a scope key from a collection address
    function _scopeFor(address collection) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(collection)));
    }

    /// @notice Buy a listed NFT (same signature & modifiers as V1) and forward incentive pool to engine.
    function buyItem(
        bytes32 listingId
    ) external payable virtual whenNotPaused nonReentrant {
        Listing storage listing = listings[listingId];

        require(listing.active, "Listing not active");
        require(block.timestamp <= listing.expiresAt, "Listing expired");
        require(msg.sender != listing.seller, "Cannot buy your own item");
        require(
            IERC721(listing.nftContract).ownerOf(listing.tokenId) ==
                listing.seller,
            "Seller no longer owns the NFT"
        );

        uint256 totalPrice = listing.price;
        uint256 platformFee = (totalPrice * platformFeeBps) / 10_000;
        uint256 royaltyFee = 0;
        address royaltyRecipient = address(0);

        // EIP-2981 royalties
        if (
            IERC165(listing.nftContract).supportsInterface(
                type(IERC2981).interfaceId
            )
        ) {
            (royaltyRecipient, royaltyFee) = IERC2981(listing.nftContract)
                .royaltyInfo(listing.tokenId, totalPrice);
        }

        // Compute pool (but only *withhold* it if engine is active)
        uint256 pBps = poolBps[listing.nftContract];
        uint256 poolAmount = pBps == 0 ? 0 : (totalPrice * pBps) / 10_000;
        bool engineActive = (incentiveEngine != address(0)) && (poolAmount > 0);

        uint256 sellerProceeds = totalPrice -
            platformFee -
            royaltyFee -
            (engineActive ? poolAmount : 0);

        if (listing.paymentToken == address(0)) {
            // Native token payment
            require(msg.value >= totalPrice, "Insufficient payment");

            // pay fees & seller
            if (platformFee > 0) payable(feeRecipient).transfer(platformFee);
            if (royaltyFee > 0 && royaltyRecipient != address(0)) {
                payable(royaltyRecipient).transfer(royaltyFee);
            }
            if (sellerProceeds > 0)
                payable(listing.seller).transfer(sellerProceeds);

            // Forward pool (native) only if engine is set
            if (engineActive) {
                bytes32 scope = _scopeFor(listing.nftContract);
                IIncentiveEngine(incentiveEngine).settleNative{
                    value: poolAmount
                }(
                    scope,
                    msg.sender, // buyer
                    listing.seller // seller
                );
                emit IncentivePoolForwarded(
                    scope,
                    msg.sender, // buyer
                    listing.seller, // seller
                    listing.nftContract, // collection
                    poolAmount
                );
            }

            // refund excess
            if (msg.value > totalPrice) {
                payable(msg.sender).transfer(msg.value - totalPrice);
            }
        } else {
            // ERC20 token payment
            require(msg.value == 0, "No native token required");
            IERC20 token = IERC20(listing.paymentToken);

            require(
                token.transferFrom(msg.sender, address(this), totalPrice),
                "Payment transfer failed"
            );

            // pay fees & seller
            if (platformFee > 0) {
                require(
                    token.transfer(feeRecipient, platformFee),
                    "Platform fee xfer failed"
                );
            }
            if (royaltyFee > 0 && royaltyRecipient != address(0)) {
                require(
                    token.transfer(royaltyRecipient, royaltyFee),
                    "Royalty xfer failed"
                );
            }
            if (sellerProceeds > 0) {
                require(
                    token.transfer(listing.seller, sellerProceeds),
                    "Seller xfer failed"
                );
            }

            // Forward pool (ERC20) only if engine is set
            if (engineActive) {
                bytes32 scope = _scopeFor(listing.nftContract);
                require(
                    token.approve(incentiveEngine, poolAmount),
                    "Approve failed"
                );
                IIncentiveEngine(incentiveEngine).settleERC20(
                    scope,
                    msg.sender, // buyer
                    listing.seller, // seller
                    poolAmount
                );
                emit IncentivePoolForwarded(
                    scope,
                    msg.sender, // buyer
                    listing.seller, // seller
                    listing.nftContract, // collection
                    poolAmount
                );
            }
        }

        // Transfer NFT to buyer
        IERC721(listing.nftContract).safeTransferFrom(
            listing.seller,
            msg.sender,
            listing.tokenId
        );

        // Deactivate listing & remove from index
        _removeListing(listingId);

        emit ItemSold(
            listingId,
            msg.sender,
            listing.seller,
            totalPrice,
            platformFee,
            royaltyFee
        );
    }

    // --- V2 carry-over: allow current NFT owner to cancel ---

    /**
     * @notice Cancel by listingId, ONLY if you are the current token owner.
     * Mirrors V2 behavior; prevents index corruption by checking pointer.
     */
    function cancelAsCurrentOwnerById(
        bytes32 listingId
    ) external virtual nonReentrant {
        Listing storage l = listings[listingId];
        require(l.nftContract != address(0), "Listing not found");

        // Must be the *current* owner on the NFT contract
        require(
            IERC721(l.nftContract).ownerOf(l.tokenId) == msg.sender,
            "Not token owner"
        );

        // Ensure the pointer matches this listingId; otherwise _removeListing could corrupt the index
        require(
            activeListing[l.nftContract][l.tokenId] == listingId,
            "Stale pointer"
        );

        // Only remove if still active (if already inactive, just unlink the pointer)
        if (l.active) {
            _removeListing(listingId);
        } else {
            // In case the flag is inactive but the pointer still points here, unlink it
            delete activeListing[l.nftContract][l.tokenId];
        }

        emit ListingCancelled(listingId);
    }

    /**
     * @notice Cancel by (nftContract, tokenId), ONLY if you are the current token owner.
     * No need to know listingId. Mirrors V2 behavior.
     */
    function cancelAsCurrentOwnerByToken(
        address nftContract,
        uint256 tokenId
    ) external virtual nonReentrant {
        require(
            IERC721(nftContract).ownerOf(tokenId) == msg.sender,
            "Not token owner"
        );

        bytes32 listingId = activeListing[nftContract][tokenId];
        require(listingId != bytes32(0), "No active pointer");

        Listing storage l = listings[listingId];

        if (l.active) {
            _removeListing(listingId);
        } else {
            // Stale pointer -> just unlink safely
            delete activeListing[nftContract][tokenId];
        }

        emit ListingCancelled(listingId);
    }

    // Optional identifier
    function version() external pure virtual returns (string memory) {
        return "GameMarketplace V3 (rebase + incentive pool forwarding)";
    }
}

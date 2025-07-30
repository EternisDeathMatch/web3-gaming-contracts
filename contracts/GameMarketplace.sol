// File: GameMarketplace.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/common/ERC2981Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title GameMarketplace
 * @dev Secure marketplace for trading gaming NFTs with royalty support
 */
contract GameMarketplace is
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable,
    AccessControlUpgradeable
{
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

    // Events
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
    ) external whenNotPaused nonReentrant {
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
    ) external whenNotPaused nonReentrant {
        _createListing(nftContract, tokenId, paymentToken, price, duration);
    }

    /// @notice Buy a listed NFT
    function buyItem(
        bytes32 listingId
    ) external payable whenNotPaused nonReentrant {
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
        uint256 platformFee = (totalPrice * platformFeeBps) / 10000;
        uint256 royaltyFee = 0;
        address royaltyRecipient = address(0);

        // Check for royalties (EIP-2981)
        if (
            IERC165(listing.nftContract).supportsInterface(
                type(IERC2981).interfaceId
            )
        ) {
            (royaltyRecipient, royaltyFee) = IERC2981(listing.nftContract)
                .royaltyInfo(listing.tokenId, totalPrice);
        }

        uint256 sellerProceeds = totalPrice - platformFee - royaltyFee;

        // Handle payment
        if (listing.paymentToken == address(0)) {
            // Native token payment
            require(msg.value >= totalPrice, "Insufficient payment");

            // Transfer fees and proceeds
            if (platformFee > 0) {
                payable(feeRecipient).transfer(platformFee);
            }
            if (royaltyFee > 0 && royaltyRecipient != address(0)) {
                payable(royaltyRecipient).transfer(royaltyFee);
            }
            payable(listing.seller).transfer(sellerProceeds);

            // Refund excess payment
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

            // Transfer fees and proceeds
            if (platformFee > 0) {
                require(
                    token.transfer(feeRecipient, platformFee),
                    "Platform fee transfer failed"
                );
            }
            if (royaltyFee > 0 && royaltyRecipient != address(0)) {
                require(
                    token.transfer(royaltyRecipient, royaltyFee),
                    "Royalty transfer failed"
                );
            }
            require(
                token.transfer(listing.seller, sellerProceeds),
                "Seller payment failed"
            );
        }

        // Transfer NFT
        IERC721(listing.nftContract).safeTransferFrom(
            listing.seller,
            msg.sender,
            listing.tokenId
        );

        // Mark listing as inactive & remove index
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

    /// @notice Cancel an active listing
    function cancelListing(bytes32 listingId) external nonReentrant {
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
    ) external nonReentrant {
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
        if (offset >= total) return new bytes32[](0);
        uint256 end = offset + limit;
        if (end > total) end = total;
        bytes32[] memory page = new bytes32[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            page[i - offset] = activeListingIds[i];
        }
        return page;
    }

    /// @notice Get all listings for a given NFT contract
    function getListingsByNFTContract(
        address nftContract
    ) external view returns (bytes32[] memory) {
        uint256 count;
        // Count matching
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
    function updatePlatformFee(uint256 newFeeBps) external onlyAdmin {
        require(newFeeBps <= 1000, "Max 10% fee");
        platformFeeBps = newFeeBps;
        emit PlatformFeeUpdated(newFeeBps);
    }

    /// @notice Update fee recipient
    function updateFeeRecipient(address newRecipient) external onlyAdmin {
        require(newRecipient != address(0), "Invalid recipient");
        feeRecipient = newRecipient;
    }
    function addSupportedToken(address token) external onlyAdmin {
        supportedTokens[token] = true;
    }

    /** @dev Remove supported payment token (owner only) */
    function removeSupportedToken(address token) external onlyAdmin {
        require(token != address(0), "Cannot remove native token support");
        supportedTokens[token] = false;
    }

    /** @dev Pause marketplace (owner only) */
    function pause() external onlyAdmin {
        _pause();
    }

    /** @dev Unpause marketplace (owner only) */
    function unpause() external onlyAdmin {
        _unpause();
    }
}

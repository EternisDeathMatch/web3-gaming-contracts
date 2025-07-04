
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";

/**
 * @title GameMarketplace
 * @dev Secure marketplace for trading gaming NFTs with royalty support
 */
contract GameMarketplace is ReentrancyGuard, Pausable, Ownable {
    
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
    uint256 public platformFeeBps = 250; // 2.5%
    address public feeRecipient;
    
    // Mapping from listing ID to listing details
    mapping(bytes32 => Listing) public listings;
    
    // Mapping to track active listings per NFT
    mapping(address => mapping(uint256 => bytes32)) public activeListing;
    
    // Supported payment tokens
    mapping(address => bool) public supportedTokens;

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

    constructor(address _feeRecipient) {
        feeRecipient = _feeRecipient;
        // Support native token by default
        supportedTokens[address(0)] = true;
    }

    /**
     * @dev List an NFT for sale
     */
    function listItem(
        address nftContract,
        uint256 tokenId,
        address paymentToken,
        uint256 price,
        uint256 duration
    ) external whenNotPaused nonReentrant {
        require(price > 0, "Price must be greater than 0");
        require(duration > 0, "Duration must be greater than 0");
        require(supportedTokens[paymentToken], "Payment token not supported");
        require(
            IERC721(nftContract).ownerOf(tokenId) == msg.sender,
            "Not the owner of the NFT"
        );
        require(
            IERC721(nftContract).isApprovedForAll(msg.sender, address(this)) ||
            IERC721(nftContract).getApproved(tokenId) == address(this),
            "Marketplace not approved"
        );

        // Check if there's already an active listing
        bytes32 existingListingId = activeListing[nftContract][tokenId];
        if (existingListingId != bytes32(0)) {
            require(!listings[existingListingId].active, "Item already listed");
        }

        bytes32 listingId = keccak256(
            abi.encodePacked(
                msg.sender,
                nftContract,
                tokenId,
                block.timestamp,
                block.number
            )
        );

        uint256 expiresAt = block.timestamp + duration;

        listings[listingId] = Listing({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            paymentToken: paymentToken,
            price: price,
            expiresAt: expiresAt,
            active: true
        });

        activeListing[nftContract][tokenId] = listingId;

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

    /**
     * @dev Buy a listed NFT
     */
    function buyItem(bytes32 listingId) external payable whenNotPaused nonReentrant {
        Listing storage listing = listings[listingId];
        
        require(listing.active, "Listing not active");
        require(block.timestamp <= listing.expiresAt, "Listing expired");
        require(msg.sender != listing.seller, "Cannot buy your own item");
        require(
            IERC721(listing.nftContract).ownerOf(listing.tokenId) == listing.seller,
            "Seller no longer owns the NFT"
        );

        uint256 totalPrice = listing.price;
        uint256 platformFee = (totalPrice * platformFeeBps) / 10000;
        uint256 royaltyFee = 0;
        address royaltyRecipient = address(0);

        // Check for royalties (EIP-2981)
        if (IERC165(listing.nftContract).supportsInterface(type(IERC2981).interfaceId)) {
            (royaltyRecipient, royaltyFee) = IERC2981(listing.nftContract).royaltyInfo(
                listing.tokenId,
                totalPrice
            );
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
                require(token.transfer(feeRecipient, platformFee), "Platform fee transfer failed");
            }
            if (royaltyFee > 0 && royaltyRecipient != address(0)) {
                require(token.transfer(royaltyRecipient, royaltyFee), "Royalty transfer failed");
            }
            require(token.transfer(listing.seller, sellerProceeds), "Seller payment failed");
        }

        // Transfer NFT
        IERC721(listing.nftContract).safeTransferFrom(
            listing.seller,
            msg.sender,
            listing.tokenId
        );

        // Mark listing as inactive
        listing.active = false;
        delete activeListing[listing.nftContract][listing.tokenId];

        emit ItemSold(
            listingId,
            msg.sender,
            listing.seller,
            totalPrice,
            platformFee,
            royaltyFee
        );
    }

    /**
     * @dev Cancel a listing
     */
    function cancelListing(bytes32 listingId) external nonReentrant {
        Listing storage listing = listings[listingId];
        
        require(listing.active, "Listing not active");
        require(msg.sender == listing.seller, "Not the seller");

        listing.active = false;
        delete activeListing[listing.nftContract][listing.tokenId];

        emit ListingCancelled(listingId);
    }

    /**
     * @dev Add supported payment token (owner only)
     */
    function addSupportedToken(address token) external onlyOwner {
        supportedTokens[token] = true;
    }

    /**
     * @dev Remove supported payment token (owner only)
     */
    function removeSupportedToken(address token) external onlyOwner {
        require(token != address(0), "Cannot remove native token support");
        supportedTokens[token] = false;
    }

    /**
     * @dev Update platform fee (owner only)
     */
    function updatePlatformFee(uint256 _newFeeBps) external onlyOwner {
        require(_newFeeBps <= 1000, "Fee cannot exceed 10%");
        platformFeeBps = _newFeeBps;
        emit PlatformFeeUpdated(_newFeeBps);
    }

    /**
     * @dev Update fee recipient (owner only)
     */
    function updateFeeRecipient(address _newRecipient) external onlyOwner {
        require(_newRecipient != address(0), "Invalid fee recipient");
        feeRecipient = _newRecipient;
    }

    /**
     * @dev Pause marketplace (owner only)
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause marketplace (owner only)
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Get listing details
     */
    function getListing(bytes32 listingId) external view returns (Listing memory) {
        return listings[listingId];
    }

    /**
     * @dev Check if listing is valid and active
     */
    function isListingValid(bytes32 listingId) external view returns (bool) {
        Listing memory listing = listings[listingId];
        return listing.active && 
               block.timestamp <= listing.expiresAt &&
               IERC721(listing.nftContract).ownerOf(listing.tokenId) == listing.seller;
    }
}

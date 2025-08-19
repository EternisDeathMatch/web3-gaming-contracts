// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./GameMarketplace.sol"; // your deployed V1 (same storage layout)
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title GameMarketplaceV2
 * @dev Manual unlisting by the *current* NFT owner.
 * - No storage changes.
 * - No changes to list/buy logic.
 * - Uses base _removeListing(...) after verifying pointer membership.
 */
contract GameMarketplaceV2 is GameMarketplace {
    function version() external pure returns (string memory) {
        return "GameMarketplace V2 (manual unlist by current token owner)";
    }

    /**
     * @notice Cancel by listingId, ONLY if you are the current token owner.
     * Requires that the active pointer points to this listingId (prevents index corruption).
     */
    function cancelAsCurrentOwnerById(bytes32 listingId) external nonReentrant {
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

        // Only remove if still active (idempotent UX: if already inactive, just unlink the pointer)
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
     * No need to know listingId.
     */
    function cancelAsCurrentOwnerByToken(
        address nftContract,
        uint256 tokenId
    ) external nonReentrant {
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

    // // UUPS auth unchanged
    // function _authorizeUpgrade(
    //     address newImplementation
    // ) internal override onlyAdmin {}
}

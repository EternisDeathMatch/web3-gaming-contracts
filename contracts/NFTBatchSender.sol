// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title NFTBatchSender
 * @notice Stateless, non-custodial batch transfer helper for ERC-721.
 * - Transfers ONLY from msg.sender (never pulls from others).
 * - Requires user-set operator approval (setApprovalForAll).
 * - Pausable kill-switch.
 * - Enforces a sane max batch size to avoid OOG.
 * - Validates collections via ERC165 (IERC721).
 */
contract NFTBatchSender is Ownable2Step, Pausable, ReentrancyGuard {
    // ======== Errors ========
    error LengthMismatch();
    error ZeroAddress();
    error NotApprovedForAll();
    error NotOwner();
    error NotERC721();
    error BatchTooLarge(uint256 given, uint256 max);

    // ======== Constants ========
    bytes4 private constant _IID_ERC721 = 0x80ac58cd; // IERC721
    uint256 public immutable MAX_BATCH; // e.g., 100

    // ======== Events ========
    // Detailed (arrays) – handy for indexing small/medium batches
    event BatchSendToOne(
        address indexed sender,
        address indexed collection,
        address indexed to,
        uint256[] tokenIds
    );
    event BatchSend1to1(
        address indexed sender,
        address indexed collection,
        address[] recipients,
        uint256[] tokenIds
    );
    event BatchSendMixed(
        address indexed sender,
        address[] collections,
        address[] recipients,
        uint256[] tokenIds
    );

    // Lightweight summaries – cheap to index for very large batches
    event BatchSummary(
        address indexed sender,
        address indexed collection,
        address indexed to,
        uint256 count
    );
    event BatchSummaryMixed(
        address indexed sender,
        uint256 uniqueCollections,
        uint256 count
    );

    // ======== Constructor ========
    constructor(uint256 maxBatch_, address initialOwner) Ownable(initialOwner) {
        require(maxBatch_ > 0, "maxBatch=0");
        MAX_BATCH = maxBatch_;
    }

    // ======== Public API ========

    /// @notice SAME collection -> ONE recipient.
    function batchSendToOne(
        address collection,
        address to,
        uint256[] calldata tokenIds
    ) external whenNotPaused nonReentrant {
        if (collection == address(0) || to == address(0)) revert ZeroAddress();
        uint256 n = tokenIds.length;
        if (n == 0) return; // no-op
        if (n > MAX_BATCH) revert BatchTooLarge(n, MAX_BATCH);
        _mustBeERC721(collection);

        IERC721 erc = IERC721(collection);
        if (!erc.isApprovedForAll(msg.sender, address(this)))
            revert NotApprovedForAll();

        for (uint256 i; i < n; ) {
            if (erc.ownerOf(tokenIds[i]) != msg.sender) revert NotOwner();
            erc.safeTransferFrom(msg.sender, to, tokenIds[i]);
            unchecked {
                ++i;
            }
        }

        emit BatchSendToOne(msg.sender, collection, to, tokenIds);
        emit BatchSummary(msg.sender, collection, to, n);
    }

    /// @notice SAME collection -> MANY recipients (1:1 mapping).
    function batchSendSameCollection(
        address collection,
        address[] calldata recipients,
        uint256[] calldata tokenIds
    ) external whenNotPaused nonReentrant {
        if (collection == address(0)) revert ZeroAddress();
        uint256 n = tokenIds.length;
        if (n == 0) return;
        if (n != recipients.length) revert LengthMismatch();
        if (n > MAX_BATCH) revert BatchTooLarge(n, MAX_BATCH);
        _mustBeERC721(collection);

        IERC721 erc = IERC721(collection);
        if (!erc.isApprovedForAll(msg.sender, address(this)))
            revert NotApprovedForAll();

        for (uint256 i; i < n; ) {
            address to = recipients[i];
            if (to == address(0)) revert ZeroAddress();
            if (erc.ownerOf(tokenIds[i]) != msg.sender) revert NotOwner();
            erc.safeTransferFrom(msg.sender, to, tokenIds[i]);
            unchecked {
                ++i;
            }
        }

        emit BatchSend1to1(msg.sender, collection, recipients, tokenIds);
        // Use address(0) in summary "to" when many recipients
        emit BatchSummary(msg.sender, collection, address(0), n);
    }

    /// @notice MIXED collections -> MANY recipients (1:1 mapping).
    function batchSendMixed(
        address[] calldata collections,
        address[] calldata recipients,
        uint256[] calldata tokenIds
    ) external whenNotPaused nonReentrant {
        uint256 n = tokenIds.length;
        if (n == 0) return;
        if (collections.length != n || recipients.length != n)
            revert LengthMismatch();
        if (n > MAX_BATCH) revert BatchTooLarge(n, MAX_BATCH);

        // Cache approvals and interface checks per collection
        address lastCol;
        bool lastApproved;
        bool lastIs721;
        IERC721 erc;
        uint256 distinct;

        for (uint256 i; i < n; ) {
            address col = collections[i];
            address to = recipients[i];
            if (col == address(0) || to == address(0)) revert ZeroAddress();

            if (col != lastCol) {
                // New collection segment
                lastCol = col;
                ++distinct;

                // IERC721 + approval checks
                lastIs721 = _supportsERC721(col);
                if (!lastIs721) revert NotERC721();

                erc = IERC721(col);
                lastApproved = erc.isApprovedForAll(msg.sender, address(this));
                if (!lastApproved) revert NotApprovedForAll();
            }

            if (erc.ownerOf(tokenIds[i]) != msg.sender) revert NotOwner();
            erc.safeTransferFrom(msg.sender, to, tokenIds[i]);

            unchecked {
                ++i;
            }
        }

        emit BatchSendMixed(msg.sender, collections, recipients, tokenIds);
        emit BatchSummaryMixed(msg.sender, distinct, n);
    }

    // ======== Admin: pause/unpause ========
    function pause() external onlyOwner {
        _pause();
    }
    function unpause() external onlyOwner {
        _unpause();
    }

    // ======== Safety: reject ETH, allow dust sweep ========
    receive() external payable {
        revert("No ETH");
    }
    fallback() external payable {
        revert("No ETH");
    }

    /// @notice Sweep forced ETH (e.g., via selfdestruct) to owner.
    function sweepETH() external onlyOwner {
        // slither-disable-next-line arbitrary-send
        (bool ok, ) = payable(owner()).call{value: address(this).balance}("");
        require(ok, "SWEEP_FAILED");
    }

    // ======== Internal utils ========
    function _mustBeERC721(address collection) internal view {
        if (!_supportsERC721(collection)) revert NotERC721();
    }

    function _supportsERC721(address collection) internal view returns (bool) {
        try IERC165(collection).supportsInterface(_IID_ERC721) returns (
            bool ok
        ) {
            return ok;
        } catch {
            return false;
        }
    }
}

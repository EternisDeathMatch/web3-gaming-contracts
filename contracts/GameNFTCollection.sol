// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
// import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";

/**
 * @title GameNFTCollection
 * @dev Secure NFT collection contract for gaming assets with role-based access control
 */
contract GameNFTCollection is
    ERC721,
    ERC721Enumerable,
    AccessControl,
    Pausable,
    ReentrancyGuard,
    ERC2981
{
    // Roles
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // Collection metadata
    string public collectionDescription;
    string public baseTokenURI;
    string private _contractURI;
    mapping(uint256 => string) private _tokenURIs;

    // Supply management
    uint256 public maxSupply;
    uint256 private _tokenIdCounter;

    // Royalty info (EIP-2981)
    // address public royaltyRecipient;
    // uint256 public royaltyBps; // Basis points (100 = 1%)

    // Events
    event CollectionUpdated(string description, string baseURI);
    event RoyaltyUpdated(address recipient, uint256 bps);
    event BatchMinted(address to, uint256[] tokenIds);
    event BaseURIUpdated(string newBaseURI);

    constructor(
        string memory name,
        string memory symbol,
        string memory description,
        string memory _baseTokenURI,
        string memory initialContractURI,
        uint256 _maxSupply,
        address _admin,
        address _royaltyRecipient,
        uint96 _royaltyBps // must be uint96 for ERC2981!
    ) ERC721(name, symbol) {
        require(_maxSupply > 0, "Max supply must be greater than 0");
        require(_royaltyBps <= 1000, "Royalty cannot exceed 10%");
        require(_admin != address(0), "Invalid admin address");
        require(_royaltyRecipient != address(0), "Invalid royalty recipient");

        collectionDescription = description;
        baseTokenURI = _baseTokenURI;
        maxSupply = _maxSupply;
        // royaltyRecipient = _royaltyRecipient;
        // royaltyBps = _royaltyBps;
        _contractURI = initialContractURI;

        // Set up roles
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
        _grantRole(MINTER_ROLE, _admin);
        _setDefaultRoyalty(_royaltyRecipient, _royaltyBps); // <<--- ERC2981 standard
    }
    /// @dev If you upload “{tokenId}.json” files, append “.json” here.
    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        require(
            ownerOf(tokenId) != address(0),
            "ERC721Metadata: URI query for nonexistent token"
        );

        string memory _tokenURI = _tokenURIs[tokenId];
        // If you want to append ".json" or use a base, adjust here:
        if (bytes(_tokenURI).length > 0) {
            return _tokenURI;
        }
        return
            string(
                abi.encodePacked(
                    baseTokenURI,
                    Strings.toString(tokenId),
                    ".json"
                )
            );
    }

    /**
     * @dev Mint a single NFT to specified address
     */
    function mint(
        address to,
        string memory uri
    )
        public
        onlyRole(MINTER_ROLE)
        whenNotPaused
        nonReentrant
        returns (uint256)
    {
        require(to != address(0), "Cannot mint to zero address");
        require(_tokenIdCounter < maxSupply, "Max supply reached");
        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter += 1;

        _safeMint(to, tokenId);
        _tokenURIs[tokenId] = uri;

        return tokenId;
    }

    function contractURI() public view returns (string memory) {
        return _contractURI;
    }

    function setContractURI(
        string calldata newURI
    ) external onlyRole(ADMIN_ROLE) {
        _contractURI = newURI;
    }

    /// @notice Allows ADMIN_ROLE to update the on-chain base URI for tokenURI()
    function setBaseTokenURI(
        string calldata newBaseURI
    ) external onlyRole(ADMIN_ROLE) {
        baseTokenURI = newBaseURI;
        emit BaseURIUpdated(newBaseURI);
    }
    /**
     * @dev Batch mint multiple NFTs to specified address
     */
    function batchMint(
        address to,
        string[] memory tokenURIs
    ) public onlyRole(MINTER_ROLE) whenNotPaused nonReentrant {
        require(to != address(0), "Cannot mint to zero address");
        require(tokenURIs.length > 0, "Must mint at least one token");
        require(
            _tokenIdCounter + tokenURIs.length <= maxSupply,
            "Batch mint would exceed max supply"
        );

        uint256[] memory tokenIds = new uint256[](tokenURIs.length);

        for (uint256 i = 0; i < tokenURIs.length; i++) {
            uint256 tokenId = _tokenIdCounter;
            _tokenIdCounter += 1;

            _safeMint(to, tokenId);
            _tokenURIs[tokenId] = tokenURIs[i];
            tokenIds[i] = tokenId;
        }

        emit BatchMinted(to, tokenIds);
    }

    /**
     * @dev Update collection metadata (admin only)
     */
    function updateCollection(
        string memory description,
        string memory _baseTokenURI
    ) public onlyRole(ADMIN_ROLE) {
        collectionDescription = description;
        baseTokenURI = _baseTokenURI;
        emit CollectionUpdated(description, _baseTokenURI);
    }

    /**
     * @dev Update royalty settings (admin only)
     */
    function updateRoyalty(
        address recipient,
        uint96 bps
    ) public onlyRole(ADMIN_ROLE) {
        require(recipient != address(0), "Invalid royalty recipient");
        require(bps <= 1000, "Royalty cannot exceed 10%");
        _setDefaultRoyalty(recipient, bps);
        emit RoyaltyUpdated(recipient, bps);
    }

    /**
     * @dev Pause contract (admin only)
     */
    function pause() public onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause contract (admin only)
     */
    function unpause() public onlyRole(ADMIN_ROLE) {
        _unpause();
    }
    /**
     * @dev Get current token ID counter
     */
    function getCurrentTokenId() public view returns (uint256) {
        return _tokenIdCounter;
    }
    /**
     * @dev Get remaining supply
     */
    function getRemainingSupply() public view returns (uint256) {
        return maxSupply - _tokenIdCounter;
    }

    // Base URI for metadata
    function _baseURI() internal view override returns (string memory) {
        return baseTokenURI;
    }

    // Required overrides
    // Required OpenZeppelin v5.x overrides for multiple inheritance
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override(ERC721, ERC721Enumerable) returns (address) {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(
        address account,
        uint128 value
    ) internal override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, value);
    }

    function burn(uint256 tokenId) public onlyRole(ADMIN_ROLE) {
        _burn(tokenId);
        delete _tokenURIs[tokenId];
    }

    // function tokenURI(
    //     uint256 tokenId
    // ) public view override(ERC721, ERC721URIStorage) returns (string memory) {
    //     return super.tokenURI(tokenId);
    // }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC721, ERC721Enumerable, AccessControl, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

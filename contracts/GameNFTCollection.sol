
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title GameNFTCollection
 * @dev Secure NFT collection contract for gaming assets with role-based access control
 */
contract GameNFTCollection is 
    ERC721, 
    ERC721Enumerable, 
    ERC721URIStorage, 
    AccessControl, 
    Pausable, 
    ReentrancyGuard 
{
    using Counters for Counters.Counter;

    // Roles
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // Collection metadata
    string public collectionDescription;
    string public baseTokenURI;
    
    // Supply management
    uint256 public maxSupply;
    Counters.Counter private _tokenIdCounter;
    
    // Royalty info (EIP-2981)
    address public royaltyRecipient;
    uint256 public royaltyBps; // Basis points (100 = 1%)

    // Events
    event CollectionUpdated(string description, string baseURI);
    event RoyaltyUpdated(address recipient, uint256 bps);
    event BatchMinted(address to, uint256[] tokenIds);

    constructor(
        string memory name,
        string memory symbol,
        string memory description,
        string memory _baseTokenURI,
        uint256 _maxSupply,
        address _admin,
        address _royaltyRecipient,
        uint256 _royaltyBps
    ) ERC721(name, symbol) {
        require(_maxSupply > 0, "Max supply must be greater than 0");
        require(_royaltyBps <= 1000, "Royalty cannot exceed 10%");
        require(_admin != address(0), "Invalid admin address");
        require(_royaltyRecipient != address(0), "Invalid royalty recipient");

        collectionDescription = description;
        baseTokenURI = _baseTokenURI;
        maxSupply = _maxSupply;
        royaltyRecipient = _royaltyRecipient;
        royaltyBps = _royaltyBps;

        // Set up roles
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
        _grantRole(MINTER_ROLE, _admin);
    }

    /**
     * @dev Mint a single NFT to specified address
     */
    function mint(
        address to,
        string memory uri
    ) public onlyRole(MINTER_ROLE) whenNotPaused nonReentrant returns (uint256) {
        require(to != address(0), "Cannot mint to zero address");
        require(_tokenIdCounter.current() < maxSupply, "Max supply reached");
        
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        
        _safeMint(to, tokenId);
        // _setTokenURI(tokenId, tokenURI);
        _setTokenURI(tokenId, uri);
        
        return tokenId;
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
            _tokenIdCounter.current() + tokenURIs.length <= maxSupply,
            "Batch mint would exceed max supply"
        );

        uint256[] memory tokenIds = new uint256[](tokenURIs.length);
        
        for (uint256 i = 0; i < tokenURIs.length; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            
            _safeMint(to, tokenId);
            _setTokenURI(tokenId, tokenURIs[i]);
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
        address _royaltyRecipient,
        uint256 _royaltyBps
    ) public onlyRole(ADMIN_ROLE) {
        require(_royaltyRecipient != address(0), "Invalid royalty recipient");
        require(_royaltyBps <= 1000, "Royalty cannot exceed 10%");
        
        royaltyRecipient = _royaltyRecipient;
        royaltyBps = _royaltyBps;
        emit RoyaltyUpdated(_royaltyRecipient, _royaltyBps);
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
        return _tokenIdCounter.current();
    }

    /**
     * @dev Get remaining supply
     */
    function getRemainingSupply() public view returns (uint256) {
        return maxSupply - _tokenIdCounter.current();
    }

    /**
     * @dev Check royalty info (EIP-2981)
     */
    function royaltyInfo(uint256, uint256 salePrice)
        public
        view
        returns (address receiver, uint256 royaltyAmount)
    {
        receiver = royaltyRecipient;
        royaltyAmount = (salePrice * royaltyBps) / 10000;
    }

    // Base URI for metadata
    function _baseURI() internal view override returns (string memory) {
        return baseTokenURI;
    }

    // Required overrides
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Enumerable) whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage, AccessControl)
        returns (bool)
    {
        return
            interfaceId == 0x2a55205a || // EIP-2981 royalty standard
            super.supportsInterface(interfaceId);
    }
}

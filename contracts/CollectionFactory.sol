// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./GameNFTCollection.sol";
// import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
/**
 * @title CollectionFactory
 * @dev Factory contract for deploying GameNFTCollection contracts
 */
contract CollectionFactory is
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // Deployment fee in wei
    uint256 public deploymentFee;

    // Platform fee recipient
    address public feeRecipient;

    // Mapping to track deployed collections
    mapping(address => bool) public isDeployedCollection;
    mapping(address => address[]) public userCollections;
    mapping(uint256 => address[]) public gameCollections;
    mapping(address => string) public collectionBaseURI;
    mapping(address => string) public collectionContractURI;

    // Array of all deployed collections
    address[] public allCollections;

    // Events
    event CollectionDeployed(
        address indexed collection,
        address indexed creator,
        uint256 indexed gameId,
        string name,
        string symbol,
        uint256 maxSupply
    );
    event CollectionBaseURIUpdated(
        address indexed collection,
        string baseTokenURI
    );
    event CollectionContractURIUpdated(
        address indexed collection,
        string contractURI
    );
    event DeploymentFeeUpdated(uint256 newFee);
    event FeeRecipientUpdated(address newRecipient);

    function initialize(
        uint256 _deploymentFee,
        address _feeRecipient
    ) public initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        deploymentFee = _deploymentFee;
        feeRecipient = _feeRecipient;
        // Grant roles to deployer
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    function _authorizeUpgrade(
        address
    ) internal override onlyRole(ADMIN_ROLE) {}
    function addAdmin(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(ADMIN_ROLE, account);
    }

    function removeAdmin(
        address account
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(ADMIN_ROLE, account);
    }

    /**
     * @dev Deploy a new GameNFTCollection contract
     */
    function deployCollection(
        uint256 gameId,
        string memory name,
        string memory symbol,
        string memory description,
        string memory baseTokenURI,
        string memory contractURI,
        uint256 maxSupply,
        address royaltyRecipient,
        uint96 royaltyBps
    ) external payable nonReentrant onlyRole(ADMIN_ROLE) returns (address) {
        require(msg.value >= deploymentFee, "Insufficient deployment fee");
        require(bytes(name).length > 0, "Name cannot be empty");
        require(bytes(symbol).length > 0, "Symbol cannot be empty");
        require(maxSupply > 0, "Max supply must be greater than 0");

        // Deploy new collection contract
        GameNFTCollection collection = new GameNFTCollection(
            name,
            symbol,
            description,
            baseTokenURI,
            contractURI,
            maxSupply,
            msg.sender, // Creator becomes admin
            royaltyRecipient,
            royaltyBps
        );

        address collectionAddress = address(collection);
        collectionBaseURI[collectionAddress] = baseTokenURI;
        collectionContractURI[collectionAddress] = contractURI;
        // Track the deployed collection
        isDeployedCollection[collectionAddress] = true;
        userCollections[msg.sender].push(collectionAddress);
        allCollections.push(collectionAddress);
        gameCollections[gameId].push(collectionAddress);

        // Transfer deployment fee to fee recipient
        if (msg.value > 0 && feeRecipient != address(0)) {
            payable(feeRecipient).transfer(msg.value);
        }

        emit CollectionDeployed(
            collectionAddress,
            msg.sender,
            gameId,
            name,
            symbol,
            maxSupply
        );
        emit CollectionContractURIUpdated(collectionAddress, contractURI);
        return collectionAddress;
    }

    /// @notice Change the baseTokenURI for an already‐deployed collection
    function setCollectionBaseURI(
        address collection,
        string calldata baseURI
    ) external {
        require(isDeployedCollection[collection], "Unknown collection");
        // only Factory owner OR the collection's ADMIN_ROLE
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender) ||
                GameNFTCollection(collection).hasRole(
                    GameNFTCollection(collection).ADMIN_ROLE(),
                    msg.sender
                ),
            "Not authorized"
        );

        collectionBaseURI[collection] = baseURI;
        GameNFTCollection(collection).setBaseTokenURI(baseURI);
        emit CollectionBaseURIUpdated(collection, baseURI);
    }

    /// @notice Change the contractURI for an already‐deployed collection
    function setCollectionContractURI(
        address collection,
        string calldata uri
    ) external {
        require(isDeployedCollection[collection], "Unknown collection");
        // only Factory owner OR the collection's ADMIN_ROLE
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender) ||
                GameNFTCollection(collection).hasRole(
                    GameNFTCollection(collection).ADMIN_ROLE(),
                    msg.sender
                ),
            "Not authorized"
        );
        collectionContractURI[collection] = uri;
        GameNFTCollection(collection).setContractURI(uri);
        emit CollectionContractURIUpdated(collection, uri);
    }

    /// @notice Return all collections under a given game
    function getGameCollections(
        uint256 gameId
    ) external view returns (address[] memory) {
        return gameCollections[gameId];
    }
    /**
     * @dev Get collections created by a user
     */
    function getUserCollections(
        address user
    ) external view returns (address[] memory) {
        return userCollections[user];
    }

    /**
     * @dev Get total number of deployed collections
     */
    function getTotalCollections() external view returns (uint256) {
        return allCollections.length;
    }

    /**
     * @dev Update deployment fee (owner only)
     */
    function updateDeploymentFee(
        uint256 _newFee
    ) external onlyRole(ADMIN_ROLE) {
        deploymentFee = _newFee;
        emit DeploymentFeeUpdated(_newFee);
    }

    /**
     * @dev Update fee recipient (owner only)
     */
    function updateFeeRecipient(
        address _newRecipient
    ) external onlyRole(ADMIN_ROLE) {
        require(_newRecipient != address(0), "Invalid fee recipient");
        feeRecipient = _newRecipient;
        emit FeeRecipientUpdated(_newRecipient);
    }

    /**
     * @dev Withdraw accumulated fees (owner only)
     */
    function withdrawFees() external onlyRole(ADMIN_ROLE) {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");
        payable(feeRecipient).transfer(balance);
    }

    /**
     * @dev Check if an address is a deployed collection
     */
    function verifyCollection(address collection) external view returns (bool) {
        return isDeployedCollection[collection];
    }
}

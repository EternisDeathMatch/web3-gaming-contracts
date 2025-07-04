
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./GameNFTCollection.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title CollectionFactory
 * @dev Factory contract for deploying GameNFTCollection contracts
 */
contract CollectionFactory is Ownable, ReentrancyGuard {
    
    // Deployment fee in wei
    uint256 public deploymentFee;
    
    // Platform fee recipient
    address public feeRecipient;
    
    // Mapping to track deployed collections
    mapping(address => bool) public isDeployedCollection;
    mapping(address => address[]) public userCollections;
    
    // Array of all deployed collections
    address[] public allCollections;
    
    // Events
    event CollectionDeployed(
        address indexed collection,
        address indexed creator,
        string name,
        string symbol,
        uint256 maxSupply
    );
    event DeploymentFeeUpdated(uint256 newFee);
    event FeeRecipientUpdated(address newRecipient);

    constructor(uint256 _deploymentFee, address _feeRecipient) {
        deploymentFee = _deploymentFee;
        feeRecipient = _feeRecipient;
    }

    /**
     * @dev Deploy a new GameNFTCollection contract
     */
    function deployCollection(
        string memory name,
        string memory symbol,
        string memory description,
        string memory baseTokenURI,
        uint256 maxSupply,
        address royaltyRecipient,
        uint256 royaltyBps
    ) external payable nonReentrant returns (address) {
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
            maxSupply,
            msg.sender, // Creator becomes admin
            royaltyRecipient,
            royaltyBps
        );

        address collectionAddress = address(collection);
        
        // Track the deployed collection
        isDeployedCollection[collectionAddress] = true;
        userCollections[msg.sender].push(collectionAddress);
        allCollections.push(collectionAddress);

        // Transfer deployment fee to fee recipient
        if (msg.value > 0 && feeRecipient != address(0)) {
            payable(feeRecipient).transfer(msg.value);
        }

        emit CollectionDeployed(
            collectionAddress,
            msg.sender,
            name,
            symbol,
            maxSupply
        );

        return collectionAddress;
    }

    /**
     * @dev Get collections created by a user
     */
    function getUserCollections(address user) external view returns (address[] memory) {
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
    function updateDeploymentFee(uint256 _newFee) external onlyOwner {
        deploymentFee = _newFee;
        emit DeploymentFeeUpdated(_newFee);
    }

    /**
     * @dev Update fee recipient (owner only)
     */
    function updateFeeRecipient(address _newRecipient) external onlyOwner {
        require(_newRecipient != address(0), "Invalid fee recipient");
        feeRecipient = _newRecipient;
        emit FeeRecipientUpdated(_newRecipient);
    }

    /**
     * @dev Withdraw accumulated fees (owner only)
     */
    function withdrawFees() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");
        payable(owner()).transfer(balance);
    }

    /**
     * @dev Check if an address is a deployed collection
     */
    function verifyCollection(address collection) external view returns (bool) {
        return isDeployedCollection[collection];
    }
}

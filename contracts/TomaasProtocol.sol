// SPDX-License-Identifier: BSL-1.0
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

import "./TomaasRWN.sol";

// import "hardhat/console.sol";

/**
 * Profit Participation Notes (PPNs) issued in connection with operating leases protocol
 * owner, create collection, mint NFT
 * holder, owner of NFT and receive earnings from renter per monthly
 * renter, rent NFT from holder and pay earnings to holder per monthly
 * @title rental place for TomaasRWN
 * @author tomaas labs 
 * @notice 
 */
contract TomaasProtocol is 
    Initializable,
    ReentrancyGuardUpgradeable, 
    OwnableUpgradeable,
    PausableUpgradeable
{
    // Add the library methods
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;

    struct CollectionInfo {
        TomaasRWN tomaasRWN; // address of collection
        IERC20Upgradeable acceptedToken; // first we use USDC, later we will use Another Token
    }

    mapping(uint16 => CollectionInfo) private _collections;
    uint16 private _collectionCount;

    event AddNewCollection(address indexed owner, address indexed collection, address tokenAddress);
    event NFTListed(address indexed nftAddress, uint256 tokenId);
    event NFTUnlisted(address indexed nftAddress, uint256 tokenId);
    event NFTsListed(address indexed nftAddress, address indexed owner);
    event NFTsUnlisted(address indexed nftAddress, address indexed owner);

    //nftaddress => tokenListForRent
    mapping(address => EnumerableSetUpgradeable.UintSet) private _nftListForRent; 

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() initializer public {
        __Pausable_init();
        __Ownable_init();
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function addCollection(address nftAddress) 
        public 
        onlyOwner 
        nonReentrant
        returns (uint16) 
    {
        require(nftAddress != address(0), "LP: NFT Addr=0");

        TomaasRWN tomaasRWN = TomaasRWN(nftAddress); 

        address tokenAddress = tomaasRWN.getAcceptedToken();

        _collections[_collectionCount] = CollectionInfo(tomaasRWN, IERC20Upgradeable(tokenAddress));
        _collectionCount++;

        emit AddNewCollection(msg.sender, nftAddress, tokenAddress);

        // console.log("collection count: ", _collectionCount);

        return _collectionCount - 1;
    }

    function getCollections() public view returns (CollectionInfo[] memory) {
        CollectionInfo [] memory collections = new CollectionInfo[](_collectionCount);
        for (uint16 i = 0; i < _collectionCount; i++) {
            collections[i] = _collections[i];
        }
        return collections;
    }

    function _existCollection(address nftAddress) internal view returns (bool) {
        require(nftAddress != address(0), "LP: nftAddr=0");
        require(_collectionCount != 0, "LP: no collections");
        for (uint16 i = 0; i < _collectionCount; i++) {
            if (address(_collections[i].tomaasRWN) == nftAddress) {
                return true;
            }
        }
        return false;
    }

    function getCollectionIndex(address nftAddress) public view returns (uint16) {
        require(nftAddress != address(0), "LP: nftAddr=0");
        require(_collectionCount != 0, "LP: no collections");
        for (uint16 i = 0; i < _collectionCount; i++) {
            if (address(_collections[i].tomaasRWN) == nftAddress) {
                return i;
            }
        }

        revert("LP: not found");
    }

    function getCollectionAt(uint16 index) external view returns (CollectionInfo memory) {
        require(index < _collectionCount, "LP: outOfBoun");
        return _collections[index];
    }

    function getCollectionInfo(address nftAddress) external view returns (CollectionInfo memory) {
        uint16 index = getCollectionIndex(nftAddress);
        require(index < _collectionCount, "LP: outOfBoun");
        return _collections[index];
    }

    function isListedNFT(address nftAddress, uint256 tokenId) public view returns (bool) {
        return EnumerableSetUpgradeable.contains(_nftListForRent[nftAddress], tokenId);
    }

    /**
     * add list for rent NFT
     * @param nftAddress address of NFT
     * @param tokenId id of NFT 
     */
    function listingNFT(address nftAddress, uint256 tokenId) public {
        uint16 index = getCollectionIndex(nftAddress);

        TomaasRWN tomaasRWN = _collections[index].tomaasRWN;

        require(tomaasRWN.ownerOf(tokenId) == msg.sender, "LP: notOwner");
        require(tomaasRWN.getApproved(tokenId) == address(this)
         || tomaasRWN.isApprovedForAll(msg.sender, address(this)), "LP: notApproved");

        EnumerableSetUpgradeable.add(_nftListForRent[nftAddress], tokenId);

        emit NFTListed(nftAddress, tokenId);
    }

    /**
     * Even if NFT is removed from the rental list, users who have already rented it continue to use it.
     * @param nftAddress address of NFT
     * @param tokenId id of NFT 
     */
    function unlistingNFT(address nftAddress, uint256 tokenId) public {
        uint16 index = getCollectionIndex(nftAddress);
        require(_collections[index].tomaasRWN.ownerOf(tokenId) == msg.sender, "LP: notOwner");
        EnumerableSetUpgradeable.remove(_nftListForRent[nftAddress], tokenId);

        emit NFTUnlisted(nftAddress, tokenId);
    }

    /**
     * add list for rent all NFTs of owner
     * @param nftAddress address of NFT
     */
    function listingNFTOwn(address nftAddress) public {
        uint16 index = getCollectionIndex(nftAddress);
        uint256 totalSupply = _collections[index].tomaasRWN.totalSupply();
        require(totalSupply > 0, "LP: no NFTs");
        require(_collections[index].tomaasRWN.isApprovedForAll(msg.sender, address(this)), "LP: notApproved");

        for (uint256 i = 0; i < totalSupply; i++) {
            if (_collections[index].tomaasRWN.ownerOf(i) == msg.sender) {
                EnumerableSetUpgradeable.add(_nftListForRent[nftAddress], i);
            }
        }

        emit NFTsListed(nftAddress, msg.sender);
    }

    function unlistingNFTOwn(address nftAddress) public {
        uint16 index = getCollectionIndex(nftAddress);
        uint256 totalSupply = _collections[index].tomaasRWN.totalSupply();
        require(totalSupply > 0, "LP: no NFTs");

        for (uint256 i = 0; i < totalSupply; i++) {
            if (_collections[index].tomaasRWN.ownerOf(i) == msg.sender) {
                EnumerableSetUpgradeable.remove(_nftListForRent[nftAddress], i);
            }
        }

        emit NFTsUnlisted(nftAddress, msg.sender);
    }

    /**
     * rent all NFTs in collection on the list for rent
     * @param nftAddress address of NFT
     * @param expires time to rent 
     */
    function rentAllNFTInCollection(address nftAddress, uint64 expires) external nonReentrant {
        require(nftAddress != address(0), "LP: nftAddr=0");

        uint16 index = getCollectionIndex(nftAddress);
        uint256 totalSupply = _collections[index].tomaasRWN.totalSupply();
        require(totalSupply > 0, "LP: no NFTs");

        for (uint256 i = 0; i < totalSupply; i++) {
            require(_collections[index].tomaasRWN.userOf(i) == address(0), "LP: isNotAvailable");
        }

        for (uint256 i = 0; i < totalSupply; i++) {
            _collections[index].tomaasRWN.setUser(i, msg.sender, expires);
        }
    }

    /**
     * rent NFT in collection on the list for rent
     * @param nftAddress address of NFT
     * @param tokenId id of NFT 
     * @param expires time to rent 
     */
    function rentNFTInCollection(address nftAddress, uint256 tokenId, uint64 expires) external nonReentrant {
        uint16 index = getCollectionIndex(nftAddress);
        _collections[index].tomaasRWN.setUser(tokenId, msg.sender, expires);
    }

    function getListingNFTs(address nftAddress) public view returns (uint256[] memory) {
        require(_existCollection(nftAddress), "LP: not found");

        uint256[] memory nftIds = new uint256[](EnumerableSetUpgradeable.length(_nftListForRent[nftAddress]));
        for (uint256 i = 0; i < EnumerableSetUpgradeable.length(_nftListForRent[nftAddress]); i++) {
            nftIds[i] = EnumerableSetUpgradeable.at(_nftListForRent[nftAddress], i);
        }
        return nftIds;
    }

    function getCountOfNFTsListed(address nftAddress) public view returns (uint256) {
        require(_existCollection(nftAddress), "LP: not found");
        return EnumerableSetUpgradeable.length(_nftListForRent[nftAddress]);
    }

    /**
     * @dev have to transfer ownership of NFT to this contract 
     * @param nftAddress address of NFT
     * @param to address to receive NFT
     * @param uri  URI of NFT
     */
    function safeMintNFT(address nftAddress, address to, string memory uri) public {
        uint16 index = getCollectionIndex(nftAddress);
        _collections[index].tomaasRWN.safeMint(to, uri);
    }
}

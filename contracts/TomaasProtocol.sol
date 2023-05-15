// SPDX-License-Identifier: BSL-1.0
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

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
contract TomaasProtocol is ReentrancyGuard, Ownable, Pausable {


    // Add the library methods
    using EnumerableSet for EnumerableSet.UintSet;

    struct CollectionInfo {
        TomaasNFT tomaasNFT; // address of collection
        IERC20 acceptedToken; // first we use USDC, later we will use Another Token
    }

    mapping(uint16 => CollectionInfo) private _collections;
    uint16 private _collectionCount;

    event AddNewCollection(address indexed owner, address indexed collection, address tokenAddress);
    event NFTListed(address indexed nftAddress, uint256 tokenId);
    event NFTUnlisted(address indexed nftAddress, uint256 tokenId);
    event NFTsListed(address indexed nftAddress, address indexed owner);
    event NFTsUnlisted(address indexed nftAddress, address indexed owner);

    //nftaddress => tokenListForRent
    mapping(address => EnumerableSet.UintSet) private _nftListForRent; 

    constructor() {
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
        require(nftAddress != address(0), "TP: NFT Addr=0");

        TomaasNFT tomaasNFT = TomaasNFT(nftAddress); 

        address tokenAddress = tomaasNFT.getAcceptedToken();

        _collections[_collectionCount] = CollectionInfo(tomaasNFT, IERC20(tokenAddress));
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
        require(nftAddress != address(0), "TP: nftAddr=0");
        require(_collectionCount != 0, "TP: no collections");
        for (uint16 i = 0; i < _collectionCount; i++) {
            if (address(_collections[i].tomaasNFT) == nftAddress) {
                return true;
            }
        }
        return false;
    }

    function getCollectionIndex(address nftAddress) public view returns (uint16) {
        require(nftAddress != address(0), "TP: nftAddr=0");
        require(_collectionCount != 0, "TP: no collections");
        for (uint16 i = 0; i < _collectionCount; i++) {
            if (address(_collections[i].tomaasNFT) == nftAddress) {
                return i;
            }
        }

        revert("TP: not found");
    }

    function getCollectionAt(uint16 index) external view returns (CollectionInfo memory) {
        require(index < _collectionCount, "TP: outOfBoun");
        return _collections[index];
    }

    function getCollectionInfo(address nftAddress) external view returns (CollectionInfo memory) {
        uint16 index = getCollectionIndex(nftAddress);
        require(index < _collectionCount, "TP: outOfBoun");
        return _collections[index];
    }

    function isListedNFT(address nftAddress, uint256 tokenId) public view returns (bool) {
        return EnumerableSet.contains(_nftListForRent[nftAddress], tokenId);
    }

    /**
     * add list for rent NFT
     * @param nftAddress address of NFT
     * @param tokenId id of NFT 
     */
    function listingNFT(address nftAddress, uint256 tokenId) public {
        uint16 index = getCollectionIndex(nftAddress);

        TomaasNFT tomaasNFT = _collections[index].tomaasNFT;

        require(tomaasNFT.ownerOf(tokenId) == msg.sender, "TP: notOwner");
        require(tomaasNFT.getApproved(tokenId) == address(this)
         || tomaasNFT.isApprovedForAll(msg.sender, address(this)), "TP: notApproved");

        EnumerableSet.add(_nftListForRent[nftAddress], tokenId);

        emit NFTListed(nftAddress, tokenId);
    }

    /**
     * Even if NFT is removed from the rental list, users who have already rented it continue to use it.
     * @param nftAddress address of NFT
     * @param tokenId id of NFT 
     */
    function unlistingNFT(address nftAddress, uint256 tokenId) public {
        uint16 index = getCollectionIndex(nftAddress);
        require(_collections[index].tomaasNFT.ownerOf(tokenId) == msg.sender, "TP: notOwner");
        EnumerableSet.remove(_nftListForRent[nftAddress], tokenId);

        emit NFTUnlisted(nftAddress, tokenId);
    }

    /**
     * add list for rent all NFTs of owner
     * @param nftAddress address of NFT
     */
    function listingNFTOwn(address nftAddress) public {
        uint16 index = getCollectionIndex(nftAddress);
        uint256 totalSupply = _collections[index].tomaasNFT.totalSupply();
        require(totalSupply > 0, "TP: no NFTs");
        require(_collections[index].tomaasNFT.isApprovedForAll(msg.sender, address(this)), "TP: notApproved");

        for (uint256 i = 0; i < totalSupply; i++) {
            if (_collections[index].tomaasNFT.ownerOf(i) == msg.sender) {
                EnumerableSet.add(_nftListForRent[nftAddress], i);
            }
        }

        emit NFTsListed(nftAddress, msg.sender);
    }

    function unlistingNFTOwn(address nftAddress) public {
        uint16 index = getCollectionIndex(nftAddress);
        uint256 totalSupply = _collections[index].tomaasNFT.totalSupply();
        require(totalSupply > 0, "TP: no NFTs");

        for (uint256 i = 0; i < totalSupply; i++) {
            if (_collections[index].tomaasNFT.ownerOf(i) == msg.sender) {
                EnumerableSet.remove(_nftListForRent[nftAddress], i);
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
        require(nftAddress != address(0), "TP: nftAddr=0");

        uint16 index = getCollectionIndex(nftAddress);
        uint256 totalSupply = _collections[index].tomaasNFT.totalSupply();
        require(totalSupply > 0, "TP: no NFTs");

        for (uint256 i = 0; i < totalSupply; i++) {
            require(_collections[index].tomaasNFT.userOf(i) == address(0), "TP: isNotAvailable");
        }

        for (uint256 i = 0; i < totalSupply; i++) {
            _collections[index].tomaasNFT.setUser(i, msg.sender, expires);
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
        _collections[index].tomaasNFT.setUser(tokenId, msg.sender, expires);
    }

    function getListingNFTs(address nftAddress) public view returns (uint256[] memory) {
        require(_existCollection(nftAddress), "TP: not found");

        uint256[] memory nftIds = new uint256[](EnumerableSet.length(_nftListForRent[nftAddress]));
        for (uint256 i = 0; i < EnumerableSet.length(_nftListForRent[nftAddress]); i++) {
            nftIds[i] = EnumerableSet.at(_nftListForRent[nftAddress], i);
        }
        return nftIds;
    }

    function getCountOfNFTsListed(address nftAddress) public view returns (uint256) {
        require(_existCollection(nftAddress), "TP: not found");
        return EnumerableSet.length(_nftListForRent[nftAddress]);
    }

    /**
     * @dev have to transfer ownership of NFT to this contract 
     * @param nftAddress address of NFT
     * @param to address to receive NFT
     * @param uri  URI of NFT
     */
    function safeMintNFT(address nftAddress, address to, string memory uri) public {
        uint16 index = getCollectionIndex(nftAddress);
        _collections[index].tomaasNFT.safeMint(to, uri);
    }
}

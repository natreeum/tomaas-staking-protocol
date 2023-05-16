// SPDX-License-Identifier: BSL-1.0
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "./TomaasRWN.sol";
import "./TomaasProtocol.sol";

contract TomaasMarketplace is 
    Initializable,
    ReentrancyGuardUpgradeable, 
    OwnableUpgradeable, 
    PausableUpgradeable 
{

    // Add the library methods
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;

    uint8 public salesFee;
    TomaasProtocol private tomaasProtocol;

    struct SaleInfo {
        address seller; // address of seller
        uint256 price; // price of token
        bool isAvailable; // is available for sale
    }

    //nftaddress => arrary of tokenIds list for sale in collection
    mapping(address => uint256[]) private listTokenIds;

    //nftaddress => tokenId => SaleInfo
    mapping(address => mapping(uint256 => SaleInfo)) private listForSale;

    event NFTListedForSale(address indexed collection, uint256 tokenId, uint256 price);
    event NFTBought(address indexed collection, uint256 tokenId, uint256 price);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _tomaasProtocol) initializer public {
        salesFee = 100; //1%
        tomaasProtocol = TomaasProtocol(_tomaasProtocol);
        __Pausable_init();
        __Ownable_init();
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    /**
     * @param _salesFee 1% = 100, 100% = 10000
     */
    function setProtocolFee(uint8 _salesFee) external onlyOwner {
        salesFee = _salesFee;
    } 

    /**
     * @return protocolFee protocol fee
     */
    function getSalesFee() public view returns (uint256) {
        return salesFee;
    }

    /**
     * @dev add or update list for sale info
     * @param nftAddress address of collection
     * @param tokenId tokenId of NFT
     * @param seller  address of seller
     * @param price  price of NFT
     */
    function _addListForSale(address nftAddress, uint256 tokenId, address seller, uint256 price) internal {
        if (listForSale[nftAddress][tokenId].isAvailable == false) {
            listTokenIds[nftAddress].push(tokenId); 
        }
        listForSale[nftAddress][tokenId] = SaleInfo(seller, price, true);
    }

    function _removeListForSale(address nftAddress, uint256 tokenId) internal {
        uint256[] storage ids = listTokenIds[nftAddress];
        uint256 index = ids.length;
        for (uint256 i = 0; i < ids.length; i++) {
            if (ids[i] == tokenId) {
                index = i;
                break;
            }
        }
        require(index < ids.length, "TM: tokenId is not found");
        ids[index] = ids[ids.length - 1];
        ids.pop();
        delete listForSale[nftAddress][tokenId];
    }

    /**
     * @param nftAddress address of TomaasRWN
     * @return saleInfos all NFTs for sale in collection
     */
    function _getListForSale(address nftAddress) internal view returns (SaleInfo[] memory) {
        uint256[] storage ids = listTokenIds[nftAddress];
        SaleInfo[] memory saleInfos = new SaleInfo[](ids.length);
        for (uint256 i = 0; i < ids.length; i++) {
            saleInfos[i] = listForSale[nftAddress][ids[i]];
        }
        return saleInfos;
    }

    /**
     * The ERC20 token's address must be the same as the acceptedToken in the TomaasRWN contract. 
     * @dev Frontend should obtain the applied token address from the TomaasRWN contract. 
     * @param nftAddress  address of NFT
     * @param tokenId tokenId of NFT 
     * @param price price of NFT  
     */
   function listingForSale(address nftAddress, uint256 tokenId, uint256 price) external nonReentrant {
        require(price > 0, "TM: nftAddress is the zero address or price is zero");

        TomaasProtocol.CollectionInfo memory collectionInfo = tomaasProtocol.getCollectionInfo(nftAddress);
        TomaasRWN tomaasRWN = collectionInfo.tomaasRWN;
        require(tomaasRWN.ownerOf(tokenId) == msg.sender, "TM: you are not the owner of this NFT");

        require(tomaasRWN.unClaimedEarnings(tokenId) == 0, "TM: you have rest of yield");

        _addListForSale(nftAddress, tokenId, msg.sender, price);
        emit NFTListedForSale(nftAddress, tokenId, price);
    }

    function isForSale(address nftAddress, uint256 tokenId) external view returns (bool) {
        require(listForSale[nftAddress][tokenId].price != 0, "TM: there isnot this NFT for sale");

        TomaasRWN tomaasRWN = TomaasRWN(nftAddress);
        require(listForSale[nftAddress][tokenId].seller == tomaasRWN.ownerOf(tokenId), "TM: seller is not the owner of this NFT");
        require(listForSale[nftAddress][tokenId].isAvailable, "TM: NFT is not for sale");
        return true;
    }

    function getSaleInfo(address nftAddress, uint256 tokenId) external view returns (SaleInfo memory) {
        require(listForSale[nftAddress][tokenId].price != 0, "TM: there isnot this NFT for sale");
        require(listForSale[nftAddress][tokenId].isAvailable, "TM: NFT is not for sale");

        return listForSale[nftAddress][tokenId];
    }

    /**
     * 
     * @param nftAddress  address of TomaasRWN
     * @param tokenId tokenId of TomaasRWN 
     * @param price price of TomaasRWN 
     */
    function buyNFT(address nftAddress, uint256 tokenId, uint256 price) external nonReentrant {
        require(price > 0, "TM: price is zero");

        TomaasProtocol.CollectionInfo memory collectionInfo = tomaasProtocol.getCollectionInfo(nftAddress);
        TomaasRWN tomaasRWN = TomaasRWN(nftAddress);
        require(listForSale[nftAddress][tokenId].seller == tomaasRWN.ownerOf(tokenId), "TM: seller is not the owner of this NFT");
        require(listForSale[nftAddress][tokenId].isAvailable, "TM: NFT is not for sale");
        require(listForSale[nftAddress][tokenId].price == price, "TM: price is not correct");

        uint256 priceToken = price * 10 ** 6;

        IERC20Upgradeable token = collectionInfo.acceptedToken; //it's from TomaasRWN's acceptedToken
        require(token.balanceOf(msg.sender) >= priceToken, "TM: not enough token balance");

        uint256 fee = priceToken / (salesFee / 100000);
        uint256 profit = priceToken - fee;
        require(token.transferFrom(msg.sender, listForSale[nftAddress][tokenId].seller, profit), "TM: failed to transfer token rent to contract");
        require(token.transfer(owner(), fee), "TM: failed to transfer token rent to owner");

        tomaasRWN.safeTransferFrom(listForSale[nftAddress][tokenId].seller, msg.sender, tokenId);

        listForSale[nftAddress][tokenId].seller = address(0);
        listForSale[nftAddress][tokenId].price = 0;
        listForSale[nftAddress][tokenId].isAvailable = false;
        emit NFTBought(nftAddress, tokenId, price);
    }

    /**
     * 
     * @param nftAddress address of TomaasRWN
     * @return saleInfos all NFTs for sale in collection
     */
    function getListedNFTs(address nftAddress) public view returns (SaleInfo[] memory) {
        return _getListForSale(nftAddress);
    }
}

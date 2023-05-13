// SPDX-License-Identifier: BSL-1.0
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./TomaasNFT.sol";
import "./TomaasProtocol.sol";

contract TomaasMarketplace is ReentrancyGuard, Ownable, Pausable {

    // Add the library methods
    using EnumerableSet for EnumerableSet.UintSet;

    uint8 public salesFee = 100; //1%
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

    constructor(address _tomaasProtocol) {
        tomaasProtocol = TomaasProtocol(_tomaasProtocol);
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
     * @param nftAddress address of TomaasNFT
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
     * The ERC20 token's address must be the same as the acceptedToken in the TomaasNFT contract. 
     * @dev Frontend should obtain the applied token address from the TomaasNFT contract. 
     * @param nftAddress  address of NFT
     * @param tokenId tokenId of NFT 
     * @param price price of NFT  
     */
   function listingForSale(address nftAddress, uint256 tokenId, uint256 price) external nonReentrant {
        require(price > 0, "TM: nftAddress is the zero address or price is zero");

        TomaasProtocol.CollectionInfo memory collectionInfo = tomaasProtocol.getCollectionInfo(nftAddress);
        TomaasNFT tomaasNFT = collectionInfo.tomaasNFT;
        require(tomaasNFT.ownerOf(tokenId) == msg.sender, "TM: you are not the owner of this NFT");

        require(tomaasNFT.unClaimedEarnings(tokenId) == 0, "TM: you have rest of yield");

        _addListForSale(nftAddress, tokenId, msg.sender, price);
        emit NFTListedForSale(nftAddress, tokenId, price);
    }

    function isForSale(address nftAddress, uint256 tokenId) external view returns (bool) {
        require(listForSale[nftAddress][tokenId].price != 0, "TM: there isnot this NFT for sale");

        TomaasNFT tomaasNFT = TomaasNFT(nftAddress);
        require(listForSale[nftAddress][tokenId].seller == tomaasNFT.ownerOf(tokenId), "TM: seller is not the owner of this NFT");
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
     * @param nftAddress  address of TomaasNFT
     * @param tokenId tokenId of TomaasNFT 
     * @param price price of TomaasNFT 
     */
    function buyNFT(address nftAddress, uint256 tokenId, uint256 price) external nonReentrant {
        require(price > 0, "TM: price is zero");

        TomaasProtocol.CollectionInfo memory collectionInfo = tomaasProtocol.getCollectionInfo(nftAddress);
        TomaasNFT tomaasNFT = TomaasNFT(nftAddress);
        require(listForSale[nftAddress][tokenId].seller == tomaasNFT.ownerOf(tokenId), "TM: seller is not the owner of this NFT");
        require(listForSale[nftAddress][tokenId].isAvailable, "TM: NFT is not for sale");
        require(listForSale[nftAddress][tokenId].price == price, "TM: price is not correct");

        uint256 priceToken = price * 10 ** 6;

        IERC20 token = collectionInfo.acceptedToken; //it's from TomaasNFT's acceptedToken
        require(token.balanceOf(msg.sender) >= priceToken, "TM: not enough token balance");

        uint256 fee = priceToken / (salesFee / 100000);
        uint256 profit = priceToken - fee;
        require(token.transferFrom(msg.sender, listForSale[nftAddress][tokenId].seller, profit), "TM: failed to transfer token rent to contract");
        require(token.transfer(owner(), fee), "TM: failed to transfer token rent to owner");

        tomaasNFT.safeTransferFrom(listForSale[nftAddress][tokenId].seller, msg.sender, tokenId);

        listForSale[nftAddress][tokenId].seller = address(0);
        listForSale[nftAddress][tokenId].price = 0;
        listForSale[nftAddress][tokenId].isAvailable = false;
        emit NFTBought(nftAddress, tokenId, price);
    }

    /**
     * 
     * @param nftAddress address of TomaasNFT
     * @return saleInfos all NFTs for sale in collection
     */
    function getListedNFTs(address nftAddress) public view returns (SaleInfo[] memory) {
        return _getListForSale(nftAddress);
    }
}

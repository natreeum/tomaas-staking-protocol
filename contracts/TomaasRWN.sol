// SPDX-License-Identifier: BSL-1.0
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "./IERC4907.sol";

// Uncomment this line to use console.log
import "hardhat/console.sol";

/**
 * contract provides a comprehensive implementation of an NFT rental protocol, 
 * with functions for managing user and expiry timestamps, 
 * collecting rental fees, and distributing earnings to NFT owners.
 * @title Tomaas Real World Asset NFT
 * @dev Implementation of the TomaasRWN
 * @custom:security-contact security@tomaas.ai
 */
contract TomaasRWN is
    Initializable, 
    ERC721Upgradeable, 
    ERC721URIStorageUpgradeable, 
    PausableUpgradeable, 
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    IERC4907
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    CountersUpgradeable.Counter private _tokenIdCounter;

    struct UserInfo {
        address user; // address of user role
        uint64 expires; // unix timestamp, user expires
    }

    //info of real world asset
    struct AssetInfo {
        uint64 svcStartDate; // unix timestamp, service start date of asset, start depreciation from this date
        uint64 usefulLife; // useful life of asset in years
        uint256 price; // price of asset
    }

    mapping(uint256 => UserInfo) internal _users;

    IERC20Upgradeable private _acceptedToken;

    uint256 _feeRate;

    AssetInfo _assetInfo;

    //token id => earnings
    mapping(uint256 => uint256) internal _unclaimedEarnings;
    uint256 internal _totalDistributedEarnings;

    event NewTRN(string name, address acceptedToken, uint64 svcStartDate, uint64 usefulLife, uint64 price);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(string memory _name, address acceptedToken, uint64 svcStartDate, uint64 usefulLife, uint64 price
    ) initializer public {
        _feeRate = 100; // 1% fee, 100% = 10000
        _acceptedToken = IERC20Upgradeable(acceptedToken);
        _assetInfo.svcStartDate = svcStartDate;
        _assetInfo.usefulLife = usefulLife;
        _assetInfo.price = price;

        __ERC721_init(_name, "TRN");
        __ERC721URIStorage_init();
        __Pausable_init();
        __Ownable_init();
        __ReentrancyGuard_init();

        emit NewTRN(_name, acceptedToken, svcStartDate, usefulLife, price);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function safeMint(address to, string memory uri) public onlyOwner {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    /**
     * @dev mint multiple tokens 
     * @param to address of user
     * @param uri  token uri
     * @param number number of tokens to mint
     */
    function safeMintMultiple(address to, string memory uri, uint64 number) public onlyOwner {
        uint256 tokenId;

        for (uint256 i = 0; i < number; i++) {
            tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            _safeMint(to, tokenId);
            _setTokenURI(tokenId, uri);
        }
    }

    /**
     * The user remains the same even if the owner is changed.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721Upgradeable) whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);

        // keep user after transfer
        // if (from != to && _users[tokenId].user != address(0)) {
        //     delete _users[tokenId];
        //     emit UpdateUser(tokenId, address(0), 0);
        // }
    }

    function _burn(
        uint256 tokenId
    ) internal override(ERC721Upgradeable, ERC721URIStorageUpgradeable) {
        super._burn(tokenId);
    }

    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721Upgradeable, ERC721URIStorageUpgradeable) returns (string memory) {
        require(_exists(tokenId), "RWN: tokenDoesNotExi");
        return super.tokenURI(tokenId);
    }

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC721Upgradeable) returns (bool) {
        return
            interfaceId == type(IERC4907).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /// @notice set the user and expires of an NFT
    /// @dev The zero address indicates there is no user
    /// Throws if `tokenId` is not valid NFT
    /// @param user  The new user of the NFT
    /// @param expires  UNIX timestamp, The new user could use the NFT before expires
    function setUser(
        uint256 tokenId,
        address user,
        uint64 expires
    ) external override {
        require(_exists(tokenId), "RWN: tokenDoesNotExi");
        require(_isApprovedOrOwner(msg.sender, tokenId), "RWN: notOwnerOrAppr");

        UserInfo storage info =  _users[tokenId];
        info.user = user;
        info.expires = expires;

        // console.log("setUser: tokenId: %s, user: %s, expires: %s", tokenId, user, expires);
        emit UpdateUser(tokenId, user, expires);
    }

    /// @notice Get the user address of an NFT
    /// @dev The zero address indicates that there is no user or the user is expired
    /// @param tokenId The NFT to get the user address for
    /// @return The user address for this NFT
    function userOf(
        uint256 tokenId
    ) external view override returns (address) {
        require(_exists(tokenId), "RWN: tokenDoesNotExi");

        // console.log("tokenId %s expires is %o and block timestamp is %o", tokenId, _users[tokenId].expires, block.timestamp);

        if( uint256(_users[tokenId].expires) >=  block.timestamp ) {
            return  _users[tokenId].user;
        }
        else {
            // console.log("tokenId %s user is expired", tokenId);
            return address(0);
        }
    }

    /// @notice Get the user expires of an NFT
    /// @dev The zero value indicates that there is no user
    /// @param tokenId The NFT to get the user expires for
    /// @return The user expires for this NFT
    function userExpires(
        uint256 tokenId
    ) external view override returns (uint256) {        
        require(_exists(tokenId), "RWN: tokenDoesNotExi");
        return _users[tokenId].expires;
    }

    function totalSupply() external view returns (uint256) {
        return _tokenIdCounter.current();
    }

    function setFeeRate(uint256 rate) external onlyOwner {
        _feeRate = rate;
    }

    function getFeeRate() external view returns (uint256) {
        return _feeRate;
    }

    function _distributeEarning(address user, uint256 amount) internal {
        uint256 rentCount = 0;
        uint256[] memory rentList = new uint256[](_tokenIdCounter.current());
        uint256 perAmount;

        for (uint256 i = 0; i < _tokenIdCounter.current(); i++) {
            if (_users[i].user == user) {
                rentList[rentCount] = i;
                rentCount++;
            }
        }

        perAmount = amount / rentCount;
        for (uint256 i = 0; i < rentCount; i++) {
            _unclaimedEarnings[rentList[i]] += perAmount;
        }
    }

    function payOutEarningsAllRented(uint256 amount) external nonReentrant {
        IERC20Upgradeable token = IERC20Upgradeable(_acceptedToken);
        require(token.balanceOf(msg.sender) >= amount, "RWN: notEnoughBalance");
        require(token.transferFrom(msg.sender, address(this), amount), "RWN: transferFailed");

        _distributeEarning(msg.sender, amount);
        _totalDistributedEarnings += amount;
    }

    function payOutEarnings(uint256 tokenId, uint256 amount) external nonReentrant {
        require(_exists(tokenId), "RWN: tokenDoesNotExi");
        require(_users[tokenId].user == msg.sender, "RWN: senderIsNotUser");

        IERC20Upgradeable token = IERC20Upgradeable(_acceptedToken);
        require(token.balanceOf(msg.sender) >= amount, "RWN: notEnoughBalance");
        require(token.transferFrom(msg.sender, address(this), amount), "RWN: transferFailed");

        _unclaimedEarnings[tokenId] += amount;
        _totalDistributedEarnings += amount;
    }

    function claimEarnings(uint256 tokenId) external nonReentrant {
        require(_exists(tokenId), "RWN: tokenDoesNotExi");
        require(ownerOf(tokenId) == msg.sender, "RWN: notOwner");

        uint256 amount = _unclaimedEarnings[tokenId];
        require(amount > 0, "RWN: noEarningsToClaim");

        uint256 fee = amount * _feeRate / 10000;
        uint256 amountToUser = amount - fee;

        IERC20Upgradeable token = IERC20Upgradeable(_acceptedToken);
        require(token.balanceOf(address(this)) >= amount, "RWN: notEnoughBalance");
        require(token.transfer(msg.sender, amountToUser), "RWN: transferFailedToUser");
        require(token.transfer(owner(), fee), "RWN: transferFailedToProtocol");

        _unclaimedEarnings[tokenId] = 0;
    }

    function claimEarningsAllRented() external nonReentrant {
        uint256 amount = 0;
        for (uint256 i = 0; i < _tokenIdCounter.current(); i++) {
            if (ownerOf(i) == msg.sender) {
                amount += _unclaimedEarnings[i];
                _unclaimedEarnings[i] = 0;
            }
        }

        require(amount > 0, "RWN: noEarningsToClaim");
        uint256 fee = amount * _feeRate / 10000;
        uint256 amountToUser = amount - fee;

        IERC20Upgradeable token = IERC20Upgradeable(_acceptedToken);
        require(token.balanceOf(address(this)) >= amount, "RWN: notEnoughBalance");
        require(token.transfer(msg.sender, amountToUser), "RWN: transferFailedToUser");
        require(token.transfer(owner(), fee), "RWN: transferFailedToProtocol");
    }

    function unClaimedEarnings(uint256 tokenId) external view returns (uint256) {
        require(_exists(tokenId), "RWN: tokenDoesNotExi");
        return _unclaimedEarnings[tokenId];
    }

    function unClaimedEarningsAll() external view returns (uint256) {
        uint256 amount = 0;

        for (uint256 i = 0; i < _tokenIdCounter.current(); i++) {
            if (ownerOf(i) == msg.sender) {
                amount += _unclaimedEarnings[i];
            }
        }
        // console.log("unClaimedEarningsAll: %s", amount);

        return amount;
    }

    function getAcceptedToken() external view returns (address) {
        return address(_acceptedToken);
    }
}

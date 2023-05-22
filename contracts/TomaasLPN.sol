// SPDX-License-Identifier: BSL-1.0
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

/**
 * @title Tomaas Liquidity Provider NFT
 * @author tomaas labs
 * @notice 
 * @custom:security-contact security@tomaas.ai
 */
contract TomaasLPN is
    Initializable,
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    ERC721URIStorageUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    CountersUpgradeable.Counter private _tokenIdCounter;
    IERC20Upgradeable private acceptedToken;

    // uint256[] public tokenIds;

    mapping(address => bool) whitelist;
    mapping(uint256 => uint256) tokenBalOfNFT;
    uint256 price;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _acceptedToken,
        uint256 _price
    ) public initializer {
        __ERC721_init("Tomaas Liquidity Provider NFT", "TLN");
        __ERC721Enumerable_init();
        __ERC721URIStorage_init();
        __Pausable_init();
        __Ownable_init();
        acceptedToken = IERC20Upgradeable(_acceptedToken);
        price = _price;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    // function safeMint(address to, string memory uri) public onlyOwner {
    //     uint256 tokenId = _tokenIdCounter.current();
    //     _tokenIdCounter.increment();
    //     _safeMint(to, tokenId);
    //     _setTokenURI(tokenId, uri);
    // }

    /**
     * safe multiple mint 
     * @param to destination address
     * @param uri token uri
     * @param num number of tokens to mint 
     */ 
    function safeMintMultiple(address to, string memory uri, uint64 num) public {
        require(
            !(acceptedToken.balanceOf(msg.sender) < price * num),
            "Not Enough Balance"
        );
        require(
            acceptedToken.transferFrom(msg.sender, address(this), price * num),
            "TLN : transferFailed"
        );

        uint256 tokenId;

        for (uint64 i = 0; i < num; i++) {
            tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            tokenBalOfNFT[tokenId] = price;
            _safeMint(to, tokenId);
            _setTokenURI(tokenId, uri);
        }
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    )
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        whenNotPaused
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    // The following functions are overrides required by Solidity.

    function _burn(
        uint256 tokenId
    ) internal override(ERC721Upgradeable, ERC721URIStorageUpgradeable) {
        super._burn(tokenId);
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}. 
     * @param tokenId token id
     */
    function tokenURI(
        uint256 tokenId
    )
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev add address to whitelist 
     * @param _address address to add to whitelist
     */
    function addToWL(address _address) public onlyOwner {
        whitelist[_address] = true;
    }

    /**
     * @dev remove address from whitelist
     * @param _address address to remove from whitelist
     */
    function rmFromWL(address _address) public onlyOwner {
        whitelist[_address] = false;
    }

    /**
     * @dev check if address is in whitelist    
     * @param _address address to check
     */
    function isWL(address _address) public view returns (bool) {
        return whitelist[_address];
    }

    /**
     * @dev WITHDRAW can only be done by whitelisted protocols. 
     * @param _tokenId token id
     */
    function withdraw(uint256 _tokenId) nonReentrant public {
        require(ownerOf(_tokenId) == msg.sender, "You are not owner");
        require(whitelist[msg.sender], "You do not have permission");
        require(
            acceptedToken.balanceOf(address(this)) >= price,
            "Contract Does not have enough token"
        );
        require(
            acceptedToken.transfer(msg.sender, tokenBalOfNFT[_tokenId]),
            "Token Transfer Failed"
        );
        require(tokenBalOfNFT[_tokenId] != 0, "Token has 0 token.");
        tokenBalOfNFT[_tokenId] = 0;
    }

    /**
     * @dev WITHDRAW can only be done by whitelisted protocols. 
     * @param _tokenIds array of token ids
     */
    function withdrawMultiple(uint256[] memory _tokenIds) public {
        require(whitelist[msg.sender], "Not whitelisted");
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            require(
                ownerOf(_tokenIds[i]) == msg.sender,
                "You entered a tokenId that is not yours"
            );
            require(tokenBalOfNFT[_tokenIds[i]] > 0, "token has no balance");
        }
        uint256 withdrawVal = 0;
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            withdrawVal += tokenBalOfNFT[_tokenIds[i]];
        }
        require(
            acceptedToken.balanceOf(address(this)) >= withdrawVal,
            "Contract Does not have enough token"
        );
        require(
            acceptedToken.transfer(msg.sender, withdrawVal),
            "Token Transfer Failed"
        );
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            tokenBalOfNFT[_tokenIds[i]] = 0;
        }
    }

    function getTokenBalOfNFT(uint256 _tokenId) public view returns (uint256) {
        return tokenBalOfNFT[_tokenId];
    }
}

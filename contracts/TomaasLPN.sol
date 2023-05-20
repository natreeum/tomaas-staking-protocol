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

/// @custom:security-contact security@tomaas.ai
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

    function safeMint_mul(address to, string memory uri, uint256 num) public {
        require(
            !(acceptedToken.balanceOf(msg.sender) < price * num),
            "Not Enough Balance"
        );
        require(
            acceptedToken.transferFrom(msg.sender, address(this), price * num),
            "TLN : transferFailed"
        );

        for (uint256 i = 0; i < num; i++) {
            uint256 tokenId = _tokenIdCounter.current();
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

    function addToWL(address _address) public onlyOwner {
        whitelist[_address] = true;
    }

    function rmFromWL(address _address) public onlyOwner {
        whitelist[_address] = false;
    }

    function isWL(address _address) public view returns (bool) {
        return whitelist[_address];
    }

    function withdrawToken(uint256 _tokenId) public {
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

    function getTokenBalOfNFT(uint256 _tokenId) public view returns (uint256) {
        return tokenBalOfNFT[_tokenId];
    }
}

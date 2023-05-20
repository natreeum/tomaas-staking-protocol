// SPDX-License-Identifier: BSL-1.0
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

import "hardhat/console.sol";

interface ITokenForRewards is IERC20Upgradeable {
    // may be not used
    function mint(address to, uint256 amount) external;
}

contract TomaasStakingPool is
    Initializable,
    ERC721HolderUpgradeable,
    OwnableUpgradeable
{
    ITokenForRewards public tokenForRewards;
    IERC721Upgradeable public liquidityProviderNft;

    // [ Data of Staking Pool Contract ]
    bool public rewardsClaimable;
    bool stakingInitialized;

    uint256 public stakingStartTime;
    uint256 public stakedTotal;

    uint256 constant stakingTime = 180 seconds;
    uint256 constant token = 10e18;

    // [ Data of Staker ]
    mapping(address => Staker) public stakerMap;

    mapping(uint256 => address) public tokenOwnerMap;

    struct Staker {
        uint256[] tokenIds;
        mapping(uint256 => uint256) tokenStakingCoolDown;
        uint256 rewardsBalance;
        uint256 rewardsReleased;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice event emitted when a user has staked a nft
    event Staked(address owner, uint256 amount);

    /// @notice event emitted when a user has unstaked a nft
    event Unstaked(address owner, uint256 amount);

    /// @notice event emitted when a user claims reward
    event RewardPaid(address indexed user, uint256 reward);

    /// @notice Allows reward tokens to be claimed
    event ClaimableStatusUpdated(bool status);

    /// @notice Emergency unstake tokens without rewards
    event EmergencyUnstake(address indexed user, uint256 tokenId);

    // function initialize() initializer public {
    function initialize(IERC721Upgradeable _liquidityProviderNft, ITokenForRewards _tokenForRewards) initializer public {
        __Ownable_init();
        tokenForRewards = _tokenForRewards;
        liquidityProviderNft = _liquidityProviderNft;
    }

    function initStaking() public onlyOwner {
        require(!stakingInitialized, "Staking is already initialized.");
        stakingStartTime = block.timestamp;
        stakingInitialized = true;
    }

    function setRewardsClaimable(bool _enabled) public onlyOwner {
        rewardsClaimable = _enabled;
        emit ClaimableStatusUpdated(_enabled);
    }

    // Staking
    function getStakedTokens(address _userAddres) public view returns (uint256[] memory tokenids) {
        return stakerMap[_userAddres].tokenIds;
    }

    function stakeToken(uint256 tokenId) public {
        require(
            block.timestamp >= stakingStartTime,
            "Staking Pool is not initialized yet"
        );
        _stake(msg.sender, tokenId);
    }

    function stakeTokens(uint256[] memory tokenIds) public {
        require(
            block.timestamp >= stakingStartTime,
            "Staking Pool is not initialized yet"
        );
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _stake(msg.sender, tokenIds[i]);
        }
    }

    function _stake(address _userAddress, uint256 _tokenId) internal {
        require(
            stakingInitialized,
            "Staking Pool is not initialized yet"
        );
        require(
            liquidityProviderNft.ownerOf(_tokenId) == _userAddress,
            "The User is not the owner of this token"
        );

        Staker storage staker = stakerMap[_userAddress];
        staker.tokenIds.push(_tokenId);
        staker.tokenStakingCoolDown[_tokenId] = block.timestamp;
        
        tokenOwnerMap[_tokenId] = _userAddress;

        liquidityProviderNft.approve(address(this), _tokenId);
        liquidityProviderNft.safeTransferFrom(_userAddress, address(this), _tokenId);

        emit Staked(_userAddress, _tokenId);
        stakedTotal++;
    }

}
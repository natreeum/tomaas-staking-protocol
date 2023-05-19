// SPDX-License-Identifier: BSL-1.0
pragma solidity ^0.8.17;

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

contract TomaasStakingPool is OwnableUpgradeable, ERC721HolderUpgradeable
{
    ITokenForRewards public tokenForRewards;
    IERC721Upgradeable public liquidityProviderNft;

    bool public rewardsClaimable;
    bool stakingInitialized;
    uint256 public stakingStartTime;

    constructor(IERC721Upgradeable _liquidityProviderNft, ITokenForRewards _tokenForRewards) {
        tokenForRewards = _tokenForRewards;
        liquidityProviderNft = _liquidityProviderNft;
    }

    function initStaking() public onlyOwner {
        require(!stakingInitialized, "Staking is already initialized.");
        stakingStartTime = block.timestamp;
        stakingInitialized = true;
    }

}
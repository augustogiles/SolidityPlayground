// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "hardhat/console.sol";
import "@thirdweb-dev/contracts/extension/upgradeable/ReentrancyGuard.sol";

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.9/contracts/token/ERC721/IERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.9/contracts/token/ERC721/ERC721.sol";
import "https://github.com/thirdweb-dev/contracts/blob/ee78bf9df7b7ac8bc8ded1c8ce91c31ef43cf73e/contracts/extension/upgradeable/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.9/contracts/security/Pausable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.9/contracts/token/ERC721/extensions/IERC721Metadata.sol";

contract BatchBurner {
  bool private locked;

  constructor() {}

  modifier lock() {
    require(!locked, "Contract is already locked");
    locked = true;
    _;
    locked = false;
  }

  function batchBurn(uint256[] memory tokenIds, address _nftContractAddress) external lock {
    IERC721 nftContract = IERC721(_nftContractAddress);

    // Check to make sure that the user who is calling the function is authorized to burn NFTs on the contract.
    require(nftContract.isApprovedForAll(msg.sender, address(this)), "User is not authorized to burn NFTs on the contract");

    for (uint256 i = 0; i < tokenIds.length; i++) {
        uint256 tokenId = tokenIds[i];
        // Check to make sure that the user who is calling the function actually owns the NFT that they are trying to burn.
        require(nftContract.ownerOf(tokenId) == msg.sender, "User must own the NFT");

        // Burn the NFT.
        nftContract.transferFrom(msg.sender, address(1), tokenId);
    }


    emit NFTsBurned(tokenIds);
  }

  event NFTsBurned(uint256[] tokenIds);
}

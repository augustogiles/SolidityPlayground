// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";    
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";


contract GotasNFTMarketplace is Ownable, ReentrancyGuard, Pausable {

    // Estrutura para representar um token NFT
    struct NFT {
        uint256 id;
        string name;
        string description;
        uint256 price;
        address owner;
    }

    uint256 public nextID;
    mapping(uint256 => NFT) public NFTs;

    struct Listing {
        address nftContractAddress;
        uint256 nftId;
        address seller;
        uint256 price;
        uint256 deadline;
        address highestBidder;
        uint256 highestBid;
        bool active;
    }

    IERC721Metadata private _nft;

    uint256[] public activeListingIds;
    uint256 public royaltyPercentage;
    uint256 public platformFeePercentage;

    address public royaltyAddress;
    address public platformFeeAddress;

    mapping(uint256 => Listing) private _listings;
    mapping(uint256 => address) private _listingOwners;

    uint256 public nextListingId = 1;

    /*event NFTListed(uint256 indexed listingId, address indexed seller, address indexed nftContract, uint256 nftId, uint256 price, uint256 deadline);*/
    event NFTSold(uint256 indexed listingId, address indexed seller, address indexed buyer, uint256 price);

    event NFTListed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event NFTMinted(uint256 indexed tokenId, address indexed to, string name, string description, string imageURI);
    event Transfer(address indexed to, address indexed from,  uint256 id);
    //event Sold(uint256 indexed tokenId, address indexed seller, address indexed buyer, uint256 price);

    constructor(uint256 _royaltyPercentage, uint256 _platformFeePercentage, address _royaltyAddress, address _platformFeeAddress) {
        require(_royaltyAddress != address(0) && _platformFeeAddress != address(0), "Addresses cannot be zero");
        royaltyPercentage = _royaltyPercentage;
        platformFeePercentage = _platformFeePercentage;
        royaltyAddress = _royaltyAddress;
        platformFeeAddress = _platformFeeAddress;

        nextID = 0;
    }


    function listNFT(address _nftContractAddress, uint256 _nftId, uint256 price, uint256 _deadline) payable external{
        require(_nft.ownerOf(_nftId) == msg.sender, "Only token owner can list");
        require(!_listings[_nftId].active, "Token already listed");

        _listings[_nftId] = Listing({
            seller: msg.sender,
            price: price,
            nftContractAddress: _nftContractAddress,
            nftId: _nftId,
            deadline: block.timestamp + _deadline,
            highestBidder: address(0),
            highestBid: 0,
            active: true
        });

        _nft.safeTransferFrom(msg.sender, address(this), _nftId);

        emit NFTListed(_nftId, msg.sender, price);
    }

    function startAuction(uint256 tokenId) public payable {
        require(_listings[tokenId].active, "Listing not found");
        require(block.timestamp < _listings[tokenId].deadline, "Deadline has passed");
        require(msg.value > _listings[tokenId].highestBid, "Bid too low");
        require(msg.sender != _listings[tokenId].seller, "Seller cannot bid");
        
        if (_listings[tokenId].highestBid > 0) {
            payable(_listings[tokenId].highestBidder).transfer(_listings[tokenId].highestBid);
        }
        
        _listings[tokenId].highestBidder = msg.sender;
        _listings[tokenId].highestBid = msg.value;
    }
    
    function endAuction(uint256 tokenId) public {
        require(_listings[tokenId].active, "Listing not found");
        require(block.timestamp >= _listings[tokenId].deadline, "Deadline not reached");
        require(msg.sender == _listings[tokenId].seller, "Only seller can end auction");
        
        if (_listings[tokenId].highestBid > 0) {
            payable(_listings[tokenId].seller).transfer(_listings[tokenId].highestBid);
            _nft.safeTransferFrom(address(this), _listings[tokenId].highestBidder, tokenId);
        }else{
            _nft.safeTransferFrom(address(this), _listings[tokenId].seller, tokenId);
        }
        
    }

    function bid(uint256 tokenId) public payable {
        require(_listings[tokenId].active, "Listing not found");
        require(block.timestamp < _listings[tokenId].deadline, "Deadline has passed");
        require(msg.value > _listings[tokenId].highestBid, "Bid too low");
        require(msg.sender != _listings[tokenId].seller, "Seller cannot bid");
        
        if (_listings[tokenId].highestBid > 0) {
            payable(_listings[tokenId].highestBidder).transfer(_listings[tokenId].highestBid);
        }
        
        _listings[tokenId].highestBidder = msg.sender;
        _listings[tokenId].highestBid = msg.value;
    }

}

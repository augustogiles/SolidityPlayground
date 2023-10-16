// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.9/contracts/token/ERC721/IERC721.sol";
import "https://github.com/thirdweb-dev/contracts/blob/ee78bf9df7b7ac8bc8ded1c8ce91c31ef43cf73e/contracts/extension/upgradeable/Ownable.sol";
import "https://github.com/thirdweb-dev/contracts/blob/ee78bf9df7b7ac8bc8ded1c8ce91c31ef43cf73e/contracts/extension/upgradeable/ReentrancyGuard.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.9/contracts/security/Pausable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.9/contracts/token/ERC721/extensions/IERC721Metadata.sol";


contract GotasNFTMarketplace is Ownable, ReentrancyGuard, Pausable {
    struct Listing {
        address nftContractAddress;
        uint256[] nftIds;  // Array of NFT IDs in the pack
        address seller;
        uint256 price;
        uint256 deadline;
        bool isFixedPrice;
        bool isListed;
        address highestBidder;
        uint256 highestBid;
    }

    struct TokenInfo {
        uint256 tokenId;
        string metadataLink;
    }

    uint256[] public activeListingIds;
    uint256 public royaltyPercentage;
    uint256 public platformFeePercentage;
    address public royaltyAddress;
    address public platformFeeAddress;

    mapping(uint256 => Listing) public listings;
    mapping(uint256 => address) public listingOwners;

    uint256 public nextListingId = 1;

    event debugBid(
        bool isUnfixedprice,
        uint256 deadline,
        uint256 blockTIMESTAMP,
        address sender
    );

    event NFTListed(
        uint256 indexed listingId,
        address indexed seller,
        address indexed nftContract,
        uint256[] nftIds,
        uint256 price,
        uint256 deadline,
        bool isFixedPrice
    );

    event NFTSold(
        uint256 indexed listingId,
        address indexed seller,
        address indexed buyer,
        uint256 price
    );


    event Bid(
        uint256 nftId,
        uint256 highestBid,
        address highestBidder
    );

    event NFTDelisted(uint256 indexed listingId);

    constructor(
        uint256 _royaltyPercentage,
        uint256 _platformFeePercentage,
        address _royaltyAddress,
        address _platformFeeAddress
    ) {
        require(
            _royaltyAddress != address(0) && _platformFeeAddress != address(0),
            "Addresses cannot be zero"
        );
        royaltyPercentage = _royaltyPercentage;
        platformFeePercentage = _platformFeePercentage;
        royaltyAddress = _royaltyAddress;
        platformFeeAddress = _platformFeeAddress;
    }

    function _canSetOwner() internal view virtual override returns (bool) {
        return true;
    }

  function listNFT(
    address _nftContractAddress,
    uint256[] memory _nftIds,
    uint256 _price,
    uint256 _deadline,
    bool _isFixedPrice
) external whenNotPaused nonReentrant {
    require(_price > 0, "Price must be greater than zero.");
    require(_deadline > 0, "Deadline must be greater than zero.");
    require(_nftIds.length > 0, "Must list at least one NFT.");
    IERC721 nftContract = IERC721(_nftContractAddress);
    for (uint256 i = 0; i < _nftIds.length; i++) {
        uint256 _nftId = _nftIds[i];

        require(
            nftContract.ownerOf(_nftId) == msg.sender,
            "You must own the NFT to list it."
        );
        // Aprovar este contrato para transferir o NFT em nome do vendedor
        nftContract.approve(address(this), _nftId);
    }
    listings[nextListingId] = Listing({
        nftContractAddress: _nftContractAddress,
        nftIds: _nftIds,
        seller: msg.sender,
        price: _price,
        deadline: block.timestamp + _deadline,
        isFixedPrice: _isFixedPrice,
        isListed: true,
        highestBidder: address(0),
        highestBid: 0
    });
    listingOwners[nextListingId] = msg.sender;
    activeListingIds.push(nextListingId);
    
    if(!_isFixedPrice){
        listings[nextListingId].highestBidder = msg.sender;
        listings[nextListingId].highestBid = _price;
    }

    emit NFTListed(
        nextListingId,
        msg.sender,
        _nftContractAddress,
        _nftIds,
        _price,
        block.timestamp + _deadline,
        _isFixedPrice
    );

    nextListingId++;
    
}

function buyNFT(uint256 _listingId)
    external
    payable
    whenNotPaused
    nonReentrant
{
    require(msg.value > 0, "Sent value must be greater than zero.");
    Listing storage listing = listings[_listingId];
    require(listing.seller != address(0), "Listing does not exist.");
    require(
        block.timestamp <= listing.deadline,
        "This listing has expired."
    );
    require(
        msg.value == listing.price,
        "Sent value must be equal to the listing price."
    );
    
    IERC721 nftContract = IERC721(listing.nftContractAddress);
    
    // Check if seller has approved this contract
    require(
        nftContract.isApprovedForAll(listing.seller, address(this)),
        "Seller must approve this contract."
    );

    uint256 royaltyAmount = (listing.price * royaltyPercentage) / 10000;
    uint256 platformFee = (listing.price * platformFeePercentage) / 10000;
    uint256 sellerAmount = listing.price - royaltyAmount - platformFee;

    for (uint256 i = 0; i < listing.nftIds.length; i++) {
        uint256 _nftId = listing.nftIds[i];
        nftContract.transferFrom(listing.seller, msg.sender, _nftId);
    }
    
    // Transfer payments
    payable(listing.seller).transfer(sellerAmount);
    payable(royaltyAddress).transfer(royaltyAmount);
    payable(platformFeeAddress).transfer(platformFee);
    
    // Emit event after transfers to ensure all went well
    emit NFTSold(_listingId, listing.seller, msg.sender, listing.price);
}


    function cancelListing(uint256 _listingId) external nonReentrant {
        require(
            listingOwners[_listingId] == msg.sender,
            "Only the listing owner can cancel it."
        );
        delete listings[_listingId];
        delete listingOwners[_listingId];
        emit NFTDelisted(_listingId);
    }

    function pause() external onlyOwner nonReentrant {
        _pause();
    }

    function unpause() external onlyOwner nonReentrant {
        _unpause();
    }

    function updateFeeAddresses(
        address _newRoyaltyAddress,
        address _newPlatformFeeAddress
    ) external onlyOwner nonReentrant {
        require(
            _newRoyaltyAddress != address(0) &&
                _newPlatformFeeAddress != address(0),
            "Addresses cannot be zero"
        );
        royaltyAddress = _newRoyaltyAddress;
        platformFeeAddress = _newPlatformFeeAddress;
    }

    function updateFeePercentages(
        uint256 _newRoyaltyPercentage,
        uint256 _newPlatformFeePercentage
    ) external onlyOwner nonReentrant {
        royaltyPercentage = _newRoyaltyPercentage;
        platformFeePercentage = _newPlatformFeePercentage;
    }

    function getAllListingIds() external view returns (uint256[] memory) {
        return activeListingIds;
    }

    function getListingInfo(uint256 _listingId)
        external
        view
        returns (TokenInfo[] memory)
    {
        Listing storage listing = listings[_listingId];
        require(listing.seller != address(0), "Listing does not exist.");
        TokenInfo[] memory tokenInfoArray = new TokenInfo[](
            listing.nftIds.length
        );
        for (uint256 i = 0; i < listing.nftIds.length; i++) {
            uint256 _nftId = listing.nftIds[i];
            string memory tokenMetadataLink = "";
            try
                IERC721Metadata(listing.nftContractAddress).tokenURI(_nftId)
            returns (string memory metadataLink) {
                tokenMetadataLink = metadataLink;
            } catch {}
            tokenInfoArray[i] = TokenInfo(_nftId, tokenMetadataLink);
        }
        return tokenInfoArray;
    }

    // Função para dar um lance em um NFT que está em leilão
    function bidNFT(uint256 nftId) external payable nonReentrant{
        Listing storage listing = listings[nftId];
        IERC721 nftContract = IERC721(listing.nftContractAddress);

        require(!listing.isFixedPrice, "Item must have in auction");
        require(block.timestamp <= listing.deadline, "Auction deadline has passed");
        require(msg.value > listing.price, "Bid must be higher than the current price");

        // Check if seller has approved this contract
        require(
            nftContract.isApprovedForAll(listing.seller, address(this)),
            "Seller must approve this contract."
        );

        // Reembolsar o lance do licitante anterior
        if (listing.highestBidder != address(0)) {
            payable(listing.highestBidder).transfer(listing.price);
        }

        // Atualizar o lance mais alto e o licitante mais alto
        listing.price = msg.value;
        listing.highestBidder = msg.sender;

        emit Bid(nftId, listing.price, listing.highestBidder);
    }

    // Função para finalizar um leilão
    function endAuction(uint256 nftId) public nonReentrant{
        Listing storage listing = listings[nftId];
        address sellerAddr = listingOwners[nftId]; 

        require(listing.deadline < block.timestamp, "Auction deadline has not passed");

        IERC721 nftContract = IERC721(listing.nftContractAddress);
    
        // Check if seller has approved this contract
        require(
            nftContract.isApprovedForAll(listing.seller, address(this)),
            "Seller must approve this contract."
        );

        uint256 royaltyAmount = (listing.price * royaltyPercentage) / 10000;
        uint256 platformFee = (listing.price * platformFeePercentage) / 10000;
        uint256 sellerAmount = listing.price - royaltyAmount - platformFee;


        delete listings[nftId];
        delete listingOwners[nftId];

        // Transfer payments
        payable(sellerAddr).transfer(sellerAmount);
        payable(royaltyAddress).transfer(royaltyAmount);
        payable(platformFeeAddress).transfer(platformFee);
        

        for (uint256 i = 0; i < listing.nftIds.length; i++) {
            uint256 _nftId = listing.nftIds[i];
            nftContract.transferFrom(listing.seller, msg.sender, _nftId);
        }

        // Emit event after transfers to ensure all went well
        emit NFTSold(nftId, sellerAddr, listing.highestBidder, listing.highestBid);           
    }
    

}

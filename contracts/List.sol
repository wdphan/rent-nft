// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;

import "./ERC4907.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// contract used in order to list an NFT token on marketplace
// Deployer: 0x54DCd05271B4DF974dEd75970b903A13BbEb319a
// Deployed to: 0x293CB7D4a0B866aEC1D4375BbAdfe688ab41b836

contract List is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private currentTokenId;

    string public baseTokenURI;
    uint256 public listPrice = 20000000000000; // 0.00002 ethers, The fee charged by the marketplace to be allowed to list an NFT - added
    uint256 public baseAmount = 20000000000000; // 0.00002 ethers
    address payable protocol; // protocol is the contract address that created the smart contract "used to be owner" - added

    // structure for store info about renting item
    struct RentableItem {
        bool rentable;
        uint256 amountPerMinute;
        address payable owner;
        address payable renter;
    }

    //the event emitted when a token is successfully listed - added
    event TokenListedSuccess(
        bool rentable,
        uint256 indexed tokenId,
        address owner
    );

    //This mapping maps tokenId to token info and is helpful when retrieving details about a tokenId
    mapping(uint256 => RentableItem) public rentables;

    constructor() ERC721("BETSU", "BTSU") {
        protocol = payable(msg.sender);
    }

    /////////////////////////////
    //////// LIST TOKEN  ////////
    /////////////////////////////

    function getListPrice() public view returns (uint256) {
        return listPrice;
    }

    function getListedTokenForId(uint256 tokenId)
        public
        view
        returns (RentableItem memory)
    {
        return rentables[tokenId];
    }

    function getCurrentToken() public view returns (uint256) {
        return currentTokenId.current();
    }

    //The first time a token is created, it is listed here
    function createToken(string memory tokenURI, uint256 price)
        public
        payable
        returns (uint256)
    {
        //Increment the tokenId counter, which is keeping track of the number of minted NFTs
        currentTokenId.increment();
        uint256 newTokenId = currentTokenId.current();

        //Mint the NFT with tokenId newTokenId to the address who called createToken
        _safeMint(msg.sender, newTokenId);

        //Map the tokenId to the tokenURI (which is an IPFS URL with the NFT metadata)
        _setTokenURI(newTokenId, tokenURI);

        //Helper function to update Global variables and emit an event
        createListedToken(newTokenId, price);

        return newTokenId;
    }

    function createListedToken(uint256 tokenId, uint256 price) private {
        //Make sure the sender sent enough ETH to pay for listing
        require(msg.value == listPrice, "Not correct price");
        //Just sanity check
        require(price > 0, "Price is negative");

        //Update the mapping of tokenId's to Token details, useful for retrieval functions
        rentables[tokenId] = RentableItem({
            rentable: false,
            amountPerMinute: baseAmount,
            owner: payable(address(this)),
            renter: payable(msg.sender)
        });

        _transfer(msg.sender, address(this), tokenId);
        //Emit the event for successful transfer. The frontend parses this message and updates the end user
        emit TokenListedSuccess(false, tokenId, address(this));
    }

    //This will return all the NFTs currently listed for rent on the marketplace
    function getAllNFTs() public view returns (RentableItem[] memory) {
        uint256 nftCount = currentTokenId.current();
        RentableItem[] memory tokens = new RentableItem[](nftCount);
        uint256 currentIndex = 0;
        uint256 currentId;
        //at the moment currentlyListed is true for all, if it becomes false in the future we will
        //filter out currentlyListed == false over here
        for (uint256 i = 0; i < nftCount; i++) {
            currentId = i + 1;
            RentableItem storage currentItem = rentables[currentId];
            tokens[currentIndex] = currentItem;
            currentIndex += 1;
        }
        //the array 'tokens' has the list of all NFTs in the marketplace
        return tokens;
    }

    //Returns all the NFTs that the current user is owner or renter in
    function getMyNFTs() public view returns (RentableItem[] memory) {
        uint256 totalItemCount = currentTokenId.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;
        uint256 currentId;
        //Important to get a count of all the NFTs that belong to the user before we can make an array for them
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (
                rentables[i + 1].owner == msg.sender ||
                rentables[i + 1].renter == msg.sender
            ) {
                itemCount += 1;
            }
        }

        //Once you have the count of relevant NFTs, create an array then store all the NFTs in it
        RentableItem[] memory items = new RentableItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (
                rentables[i + 1].owner == msg.sender ||
                rentables[i + 1].renter == msg.sender
            ) {
                currentId = i + 1;
                RentableItem storage currentItem = rentables[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }
}

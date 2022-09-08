// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;

import "./ERC4907.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// contract used to create a rental order

contract RentableNFT is ERC4907, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private currentTokenId;

    string public baseTokenURI;
    uint256 public baseAmount = 20000000000000; // 0.00002 ethers

    // structure for store info about renting item
    struct RentableItem {
        bool rentable;
        uint256 amountPerMinute;
    }

    //This mapping maps tokenId to token info and is helpful when retrieving details about a tokenId
    mapping(uint256 => RentableItem) public rentables;

    constructor(string memory _name, string memory _symbol)
        ERC4907(_name, _symbol)
    {
        baseTokenURI = "https://bafybeicrtqwqiupfregzoumecwg4bwqldm4j2pbpbrclkjiwko74ckeqzu.ipfs.dweb.link/metadata/";
    }

    // mints list of current tokens from uri.
    function mint() public onlyOwner {
        currentTokenId.increment();
        uint256 newItemId = currentTokenId.current();
        _safeMint(owner(), newItemId);
        rentables[newItemId] = RentableItem({
            rentable: false,
            amountPerMinute: baseAmount
        });
    }

    /////////////////////////////
    /////////  SET RENT  ////////
    /////////////////////////////

    function rent(uint256 _tokenId, uint64 _expires) public payable virtual {
        uint256 dueAmount = rentables[_tokenId].amountPerMinute * _expires;
        require(msg.value == dueAmount, "Uncorrect amount");
        require(userOf(_tokenId) == address(0), "Already rented");
        require(rentables[_tokenId].rentable, "Renting disabled for the NFT");
        payable(ownerOf(_tokenId)).transfer(dueAmount);
        UserInfo storage info = _users[_tokenId];
        info.user = msg.sender;
        info.expires = block.timestamp + (_expires * 60);
        emit UpdateUser(_tokenId, msg.sender, _expires);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    function setBaseTokenURI(string memory _baseTokenURI) public onlyOwner {
        baseTokenURI = _baseTokenURI;
    }

    function setRentFee(uint256 _tokenId, uint256 _amountPerMinute) public {
        require(
            _isApprovedOrOwner(_msgSender(), _tokenId),
            "Caller not owner nor approved"
        );
        rentables[_tokenId].amountPerMinute = _amountPerMinute;
    }

    function setRentable(uint256 _tokenId, bool _rentable) public {
        require(
            _isApprovedOrOwner(_msgSender(), _tokenId),
            "Caller not owner nor approved"
        );
        rentables[_tokenId].rentable = _rentable;
    }
}

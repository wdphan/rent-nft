// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./ERC721Base.sol";

contract Rent is ERC721Base {
    /////////////////////////////////////
    ////////// === STORAGE === //////////
    /////////////////////////////////////

    mapping(uint256 => address) internal _agreements;

    //////////////////////////////////////
    /////////// === EVENTS === ///////////
    //////////////////////////////////////

    event RentAgreement(
        IERC721 indexed tokenContract,
        uint256 indexed tokenID,
        address indexed user,
        address agreement
    );

    //////////////////////////////////////
    ///// === EXTERNAL FUNCTIONS === /////
    //////////////////////////////////////

    /// @notice Create rent between an owner and a user
    /// @param tokenContract ERC721 contract whose token is being rented
    /// @param tokenID id of the ERC721 token being rented
    /// @param user address of the user receiving right of use
    /// @param agreement Contract's address defining the rules of the rent. Only such contract is able to break the rent.
    /// if `agreement` is set to the zero address, no agreement are in place and both user and owner can break the rent at any time
    function create(
        IERC721 tokenContract,
        uint256 tokenID,
        address user,
        address agreement
    ) external {
        address tokenOwner = tokenContract.ownerOf(tokenID);
        require(
            msg.sender == tokenOwner ||
                _operatorsForAll[tokenOwner][msg.sender],
            "NOT_AUTHORIZED"
        );

        uint256 rent = _rentNFTOrRevert(tokenContract, tokenID);
        address rentOwner = _ownerOf(rent);
        require(rentOwner == address(0), "ALREADY_EXISTS");

        _mint(user, rent);
        _agreements[rent] = agreement;
        emit RentAgreement(tokenContract, tokenID, user, agreement);
    }

    /// @notice Destroy a specific rent. All the sub rent will also be destroyed
    /// @param tokenContract ERC721 contract whose token is being rent
    /// @param tokenID ERC721 tokenID being rent
    function destroy(IERC721 tokenContract, uint256 tokenID) external {
        uint256 rent = _rentNFT(tokenContract, tokenID);
        address rentOwner = _ownerOf(rent);
        require(rentOwner != address(0), "NOT_EXISTS");
        address agreement = _agreements[rent];
        if (agreement != address(0)) {
            require(msg.sender == agreement, "NOT_AUTHORIZED_AGREEMENT");
        } else {
            address tokenOwner = tokenContract.ownerOf(tokenID);
            require(
                msg.sender == rentOwner ||
                    _operatorsForAll[rentOwner][msg.sender] ||
                    msg.sender == tokenOwner ||
                    _operatorsForAll[tokenOwner][msg.sender],
                "NOT_AUTHORIZED"
            );
        }
        emit RentAgreement(tokenContract, tokenID, address(0), address(0));
        _burn(rentOwner, rent);

        // This recursively destroy all sub rentals, calls internal function
        _destroySubRenters(rent);
    }

    ////////////////////////////////////
    ///// === GETTER FUNCTIONS === /////
    ////////////////////////////////////

    /// @notice return the current agreement for a particular rent
    /// @param rent token id
    function getAgreement(uint256 rent) public view returns (address) {
        return _agreements[rent];
    }

    /// @notice return the current agreement for a particular tokenContract/tokenId pair
    /// @param tokenContract ERC721 contract whose token is being rented
    /// @param tokenID ERC721 tokenID being rented
    function getAgreement(IERC721 tokenContract, uint256 tokenID)
        external
        view
        returns (address)
    {
        return getAgreement(_rentNFTOrRevert(tokenContract, tokenID));
    }

    /// @notice return whether an particular token (tokenContract/tokenId pair) is being rent
    /// @param tokenContract ERC721 contract whose token is being rented
    /// @param tokenID ERC721 tokenID being rent
    function isRented(IERC721 tokenContract, uint256 tokenID)
        external
        view
        returns (bool)
    {
        return _ownerOf(_rentNFTOrRevert(tokenContract, tokenID)) != address(0);
    }

    /// @notice return the current user of a particular token (the owner of the deepest rent)
    /// The user is basically the owner of the rent of a rent of a rent (max depth = 8)
    /// @param tokenContract ERC721 contract whose token is being rented
    /// @param tokenID ERC721 tokenID being rent
    function currentUser(IERC721 tokenContract, uint256 tokenID)
        external
        view
        returns (address)
    {
        uint256 rent = _rentNFTOrRevert(tokenContract, tokenID);
        address rentOwner = _ownerOf(rent);
        if (rentOwner != address(0)) {
            // rent for this tokenContract/tokenID paire exists => get the sub-most rent recursively
            return _submostRentOwner(rent, rentOwner);
        } else {
            // there is no rent for this tokenContract/tokenID pair, the user is thus the owner
            return tokenContract.ownerOf(tokenID);
        }
    }

    /// @notice return the rentId (tokenID of the rent) based on tokenContract/tokenID pair
    /// @param tokenContract ERC721 contract whose token is being rented
    /// @param tokenID ERC721 tokenID being rented
    function rentNFT(IERC721 tokenContract, uint256 tokenID)
        external
        view
        returns (uint256)
    {
        return _rentNFTOrRevert(tokenContract, tokenID);
    }

    //////////////////////////////////////
    ///// === INTERNAL FUNCTIONS === /////
    //////////////////////////////////////

    // Rent NFT or revert
    function _rentNFTOrRevert(IERC721 tokenContract, uint256 tokenID)
        internal
        view
        returns (uint256 rent)
    {
        rent = _rentNFT(tokenContract, tokenID);
        require(rent != 0, "INVALID_RENT_MAX_DEPTH_8");
    }

    // Rent NFT returns baseId
    function _rentNFT(IERC721 tokenContract, uint256 tokenID)
        internal
        view
        returns (uint256)
    {
        uint256 baseId = uint256(
            keccak256(abi.encodePacked(tokenContract, tokenID))
        ) & 0x1FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
        if (tokenContract == this) {
            uint256 depth = ((tokenID >> 253) + 1);
            if (depth >= 8) {
                return 0;
            }
            return baseId | (depth << 253);
        }
        return baseId;
    }

    // Returns the submost rent owner (the last renter)
    function _submostRentOwner(uint256 rent, address lastRentOwner)
        internal
        view
        returns (address)
    {
        uint256 subRent = _rentNFT(this, rent);
        address subRentOwner = _ownerOf(subRent);
        if (subRentOwner != address(0)) {
            return _submostRentOwner(subRent, subRentOwner);
        } else {
            return lastRentOwner;
        }
    }

    // get rid of all subrentals
    function _destroySubRenters(uint256 rent) internal {
        uint256 subRent = _rentNFT(this, rent);
        address subRentOwner = _ownerOf(subRent);
        if (subRentOwner != address(0)) {
            emit RentAgreement(this, rent, address(0), address(0));
            _burn(subRentOwner, subRent);
            _destroySubRenters(subRent);
        }
    }
}

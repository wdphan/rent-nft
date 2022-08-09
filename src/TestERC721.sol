// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "./ERC721Base.sol";

contract TestNFT is ERC721Base {
    function mint(address to, uint256 id) external {
        require(_ownerOf(id) == address(0), "ALREADY_EXISTS");
        _mint(to, id);
    }
}

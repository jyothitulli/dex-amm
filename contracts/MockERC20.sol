// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockERC20
 * @dev Simple ERC20 token for testing the DEX AMM.
 */
contract MockERC20 is ERC20 {
    /**
     * @notice Creates a token and mints 1 million units to the deployer.
     * @param name The name of the token (e.g., "Token A")
     * @param symbol The symbol of the token (e.g., "TKA")
     */
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        // Mint 1,000,000 tokens with 18 decimal places
        _mint(msg.sender, 1000000 * 10**18); 
    }
    
    /**
     * @notice Mint tokens for testing purposes.
     * @dev In a production environment, this would be restricted to an owner.
     * @param to The address that will receive the minted tokens.
     * @param amount The amount of tokens to mint.
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
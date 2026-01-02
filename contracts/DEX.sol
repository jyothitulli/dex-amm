// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract DEX {
    // State variables
    address public tokenA;
    address public tokenB;
    uint256 public reserveA;
    uint256 public reserveB;
    uint256 public totalLiquidity;
    mapping(address => uint256) public liquidity;
    
    // Events
    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidityMinted);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidityBurned);
    event Swap(address indexed trader, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);
    
    /// @notice Initialize the DEX with two token addresses
    constructor(address _tokenA, address _tokenB) {
        tokenA = _tokenA;
        tokenB = _tokenB;
    }
    
    /// @notice Add liquidity to the pool
    function addLiquidity(uint256 amountA, uint256 amountB) 
        external 
        returns (uint256 liquidityMinted) {
        require(amountA > 0 && amountB > 0, "Amounts must be greater than 0");

        if (totalLiquidity == 0) {
            // Initial Liquidity (First Provider): liquidityMinted = sqrt(amountA * amountB)
            liquidityMinted = Math.sqrt(amountA * amountB);
        } else {
            // Subsequent providers must match the current ratio
            // amountB_required = (amountA * reserveB) / reserveA
            require(amountB >= (amountA * reserveB) / reserveA, "Incorrect liquidity ratio");
            // liquidityMinted = (amountA * totalLiquidity) / reserveA
            liquidityMinted = (amountA * totalLiquidity) / reserveA;
        }

        // Transfer tokens to contract
        IERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountB);

        // Update state
        reserveA += amountA;
        reserveB += amountB;
        totalLiquidity += liquidityMinted;
        liquidity[msg.sender] += liquidityMinted;

        emit LiquidityAdded(msg.sender, amountA, amountB, liquidityMinted);
    }
    
    /// @notice Remove liquidity from the pool
    function removeLiquidity(uint256 liquidityAmount) 
        external 
        returns (uint256 amountA, uint256 amountB) {
        require(liquidity[msg.sender] >= liquidityAmount, "Insufficient LP tokens");

        // Calculate proportional share of reserves
        // amountA = (liquidityBurned * reserveA) / totalLiquidity
        amountA = (liquidityAmount * reserveA) / totalLiquidity;
        // amountB = (liquidityBurned * reserveB) / totalLiquidity
        amountB = (liquidityAmount * reserveB) / totalLiquidity;

        // Update state
        liquidity[msg.sender] -= liquidityAmount;
        totalLiquidity -= liquidityAmount;
        reserveA -= amountA;
        reserveB -= amountB;

        // Return tokens to provider
        IERC20(tokenA).transfer(msg.sender, amountA);
        IERC20(tokenB).transfer(msg.sender, amountB);

        emit LiquidityRemoved(msg.sender, amountA, amountB, liquidityAmount);
    }
    
    /// @notice Swap token A for token B
    function swapAForB(uint256 amountAIn) 
        external 
        returns (uint256 amountBOut) {
        require(amountAIn > 0, "Amount must be greater than 0");
        
        amountBOut = getAmountOut(amountAIn, reserveA, reserveB);
        
        IERC20(tokenA).transferFrom(msg.sender, address(this), amountAIn);
        IERC20(tokenB).transfer(msg.sender, amountBOut);

        reserveA += amountAIn;
        reserveB -= amountBOut;

        emit Swap(msg.sender, tokenA, tokenB, amountAIn, amountBOut);
    }
    
    /// @notice Swap token B for token A
    function swapBForA(uint256 amountBIn) 
        external 
        returns (uint256 amountAOut) {
        require(amountBIn > 0, "Amount must be greater than 0");
        
        amountAOut = getAmountOut(amountBIn, reserveB, reserveA);
        
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountBIn);
        IERC20(tokenA).transfer(msg.sender, amountAOut);

        reserveB += amountBIn;
        reserveA -= amountAOut;

        emit Swap(msg.sender, tokenB, tokenA, amountBIn, amountAOut);
    }
    
    /// @notice Get current price of token A in terms of token B
    function getPrice() external view returns (uint256 price) {
        require(reserveA > 0, "ReserveA is 0");
        // Price of Token A = y / x
        return reserveB / reserveA;
    }
    
    /// @notice Get current reserves
    function getReserves() external view returns (uint256 _reserveA, uint256 _reserveB) {
        return (reserveA, reserveB);
    }
    
    /// @notice Calculate amount of token output for given amount of token input
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) 
        public 
        pure 
        returns (uint256 amountOut) {
        require(amountIn > 0, "Insufficient input amount");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");

        // Formula including 0.3% fee:
        // amountInWithFee = amountIn * 997
        uint256 amountInWithFee = amountIn * 997;
        // numerator = amountInWithFee * reserveOut
        uint256 numerator = amountInWithFee * reserveOut;
        // denominator = (reserveIn * 1000) + amountInWithFee
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        
        return numerator / denominator;
    }
}
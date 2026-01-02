
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title DEX AMM Protocol
 * @notice Implements a Constant Product Automated Market Maker (x * y = k)
 * @dev Inherits from OpenZeppelin ERC20 to manage LP tokens and ReentrancyGuard for safety
 */
contract DEX is ERC20, ReentrancyGuard {
    address public immutable tokenA;
    address public immutable tokenB;
    uint256 public reserveA;
    uint256 public reserveB;

    // Events
    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidityMinted);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidityBurned);
    event Swap(address indexed trader, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);

    /**
     * @notice Initializes the DEX with two token addresses
     * @param _tokenA Address of the first ERC20 token
     * @param _tokenB Address of the second ERC20 token
     */
    constructor(address _tokenA, address _tokenB) ERC20("DEX LP Token", "DEX-LP") {
        require(_tokenA != address(0) && _tokenB != address(0), "Invalid addresses");
        tokenA = _tokenA;
        tokenB = _tokenB;
    }

    /**
     * @notice Adds liquidity to the pool and mints LP tokens
     * @dev Initial liquidity uses sqrt(a*b), subsequent uses proportional ratio
     * @param amountA Amount of Token A to deposit
     * @param amountB Amount of Token B to deposit
     * @return liquidityMinted Amount of LP tokens issued to the provider
     */
    function addLiquidity(uint256 amountA, uint256 amountB) external nonReentrant returns (uint256 liquidityMinted) {
        require(amountA > 0 && amountB > 0, "Zero amounts");
        
        IERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountB);

        uint256 _totalLiquidity = totalSupply();
        if (_totalLiquidity == 0) {
            liquidityMinted = sqrt(amountA * amountB);
        } else {
            liquidityMinted = min(
                (amountA * _totalLiquidity) / reserveA,
                (amountB * _totalLiquidity) / reserveB
            );
        }

        require(liquidityMinted > 0, "Insufficient liquidity minted");
        
        reserveA += amountA;
        reserveB += amountB;
        _mint(msg.sender, liquidityMinted);

        emit LiquidityAdded(msg.sender, amountA, amountB, liquidityMinted);
    }

    /**
     * @notice Removes liquidity and returns underlying tokens
     * @param liquidityAmount Amount of LP tokens to burn
     * @return amountA Amount of Token A returned
     * @return amountB Amount of Token B returned
     */
    function removeLiquidity(uint256 liquidityAmount) external nonReentrant returns (uint256 amountA, uint256 amountB) {
        require(liquidityAmount > 0, "Invalid amount");
        uint256 _totalLiquidity = totalSupply();

        amountA = (liquidityAmount * reserveA) / _totalLiquidity;
        amountB = (liquidityAmount * reserveB) / _totalLiquidity;

        _burn(msg.sender, liquidityAmount);
        reserveA -= amountA;
        reserveB -= amountB;

        IERC20(tokenA).transfer(msg.sender, amountA);
        IERC20(tokenB).transfer(msg.sender, amountB);

        emit LiquidityRemoved(msg.sender, amountA, amountB, liquidityAmount);
    }

    /**
     * @notice Swaps Token A for Token B
     * @dev Includes a 0.3% fee (997/1000)
     * @param amountAIn Amount of Token A to swap
     * @return amountBOut Amount of Token B received
     */
    function swapAforB(uint256 amountAIn) external nonReentrant returns (uint256 amountBOut) {
        require(amountAIn > 0, "Zero input");
        amountBOut = getAmountOut(amountAIn, reserveA, reserveB);
        
        IERC20(tokenA).transferFrom(msg.sender, address(this), amountAIn);
        IERC20(tokenB).transfer(msg.sender, amountBOut);

        reserveA += amountAIn;
        reserveB -= amountBOut;

        emit Swap(msg.sender, tokenA, tokenB, amountAIn, amountBOut);
    }

    /**
     * @notice Swaps Token B for Token A
     * @dev Includes a 0.3% fee (997/1000)
     * @param amountBIn Amount of Token B to swap
     * @return amountAOut Amount of Token A received
     */
    function swapBforA(uint256 amountBIn) external nonReentrant returns (uint256 amountAOut) {
        require(amountBIn > 0, "Zero input");
        amountAOut = getAmountOut(amountBIn, reserveB, reserveA);
        
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountBIn);
        IERC20(tokenA).transfer(msg.sender, amountAOut);

        reserveB += amountBIn;
        reserveA -= amountAOut;

        emit Swap(msg.sender, tokenB, tokenA, amountBIn, amountAOut);
    }

    /**
     * @notice Calculates the current price of Token A in terms of Token B
     * @return price Price scaled by 1e18
     */
    function getPrice() external view returns (uint256 price) {
        require(reserveA > 0, "Empty pool");
        return (reserveB * 1e18) / reserveA;
    }

    /**
     * @notice Returns current reserves
     * @return _reserveA Current Token A reserve
     * @return _reserveB Current Token B reserve
     */
    function getReserves() external view returns (uint256 _reserveA, uint256 _reserveB) {
        return (reserveA, reserveB);
    }

    /**
     * @notice Pure function to calculate swap output based on x*y=k
     * @dev Deducts 0.3% fee before output calculation
     * @param amountIn Amount of input token
     * @param _reserveIn Reserve of input token
     * @param _reserveOut Reserve of output token
     * @return amountOut Calculated output amount
     */
    function getAmountOut(uint256 amountIn, uint256 _reserveIn, uint256 _reserveOut) public pure returns (uint256 amountOut) {
        require(_reserveIn > 0 && _reserveOut > 0, "Invalid reserves");
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * _reserveOut;
        uint256 denominator = (_reserveIn * 1000) + amountInWithFee;
        return numerator / denominator;
    }

    /**
     * @dev Internal square root function for initial LP calculation
     */
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    /**
     * @dev Internal helper for liquidity ratio math
     */
    function min(uint256 x, uint256 y) internal pure returns (uint256) {
        return x < y ? x : y;
    }
}

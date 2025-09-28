// SPDX-License-Identifier: GPL

pragma solidity ^0.8.27;

/// @notice Both tokens in the pair have same address.
error TokenAddressesSame();

/// @notice One of the token address is zero address.
error ZeroAddress();

/// @notice The pair already exists;
error PairExists();

/**
 * @title  ConfFactory
 * @notice The ConfFactory contract is used to facilitate creation
 * of new pairs in the AMM. It can be used by both users and devs alike.
 * Based on the uniswap v2 factory contract
 */
contract ConfFactory {
    // Mapping between the tokens and liquidity pair
    // pairs[token0][token1] ==  pairs[token1][token0] == address of the liquidity pair
    mapping(address => mapping(address => address)) public pairs;

    // The addresses of all public pairs created by ConfFactory
    address[] public pairStore;

    // @notice Returns the numbers of public pairs created by ConfFactory
    function getTotalPairs() external view returns (uint) {
        return pairStore.length;
    }

    /// @notice             Emitted when a pair is created
    /// @param token0       address of the first token in the liquidity pair
    /// @param token1       address of the second token in the liquidity pair
    /// @param pair         address of the liquidity pair
    /// @param totalPairs   the number of pairs in pairStore
    event PairCreated(address indexed token0, address indexed token1, address pair, uint totalPairs);

    /// @notice             Create a liquidity pair
    /// @param tokenA       address of the first token in the liquidity pair
    /// @param tokenB       address of the second token in the liquidity pair
    /// @return pair        address of the liquidity pair
    function createPair(address tokenA, address tokenB) external returns (address pair) {
        /// Reverting transaction if an error is encountered
        if (tokenA == tokenB) {
            revert TokenAddressesSame();
        }
        if (tokenA == address(0) || tokenB == address(0)) {
            revert ZeroAddress();
        }
        if (pairs[tokenA][tokenB] != address(0)) {
            revert PairExists();
        }

        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        /// NOTICE: Implement the construct of pair
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));

        pairs[token0][token1] = pair;
        pairs[token1][token0] = pair; // populate mapping in the reverse direction
        pairStore.push(pair);
        emit PairCreated(token0, token1, pair, pairStore.length);
    }
}

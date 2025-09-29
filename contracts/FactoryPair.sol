// SPDX-License-Identifier: MIT

pragma solidity ^0.8.27;

import {ebool, eaddress} from "@fhevm/solidity/lib/FHE.sol";
import {
    IConfidentialFungibleToken
} from "@openzeppelin/confidential-contracts/interfaces/IConfidentialFungibleToken.sol";

import {ConfidentialFungibleToken} from "@openzeppelin/confidential-contracts/token/ConfidentialFungibleToken.sol";
import {SepoliaConfig} from "@fhevm/solidity/config/ZamaConfig.sol";

/**
 * @title  FactoryPair
 * @notice This contract governs the liquidity pair created in the AMM
 * including deposit and withdrawal of liquidity, minting of liquidity of a ERC7984 to ERC7984 pair,
 * manages the asset swap rates
 * taking a deterministic path to carry out the swap action of assets.
 * The pair uses the conservation function and constant product invariant design
 * introduced in Uniswap V2
 */
contract FactoryPair {
    address public factory;
    address public token0;
    address public token1;

    error InsufficientBalance();
    error NotEnoughTokensInPool();

    constructor() {
        factory = msg.sender;
    }

    event LPTokensMinted(uint256 blockNumber, uint amount0, uint amount1, eaddress user);
    event LPTokensBurnt(uint256 blockNumber, uint amount0, uint amount1, eaddress user);
}

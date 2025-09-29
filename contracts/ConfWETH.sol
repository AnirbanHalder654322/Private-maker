// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {SepoliaConfig} from "@fhevm/solidity/config/ZamaConfig.sol";
import {IWeth} from "./ConfWrapper.sol";
import {ConfWrapper, ConfidentialFungibleToken} from "./ConfWrapper.sol";

contract ConfWETH is ConfWrapper, SepoliaConfig {
    uint256 rate = 1;

    constructor(
        IWeth token,
        string memory name,
        string memory symbol,
        string memory uri
    ) ConfWrapper(token, rate) ConfidentialFungibleToken(name, symbol, uri) {}
}

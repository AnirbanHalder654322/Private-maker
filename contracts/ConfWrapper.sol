// SPDX-License-Identifier: MIT

pragma solidity ^0.8.27;

import {FHE, externalEuint64, euint64} from "@fhevm/solidity/lib/FHE.sol";
import {ConfidentialFungibleToken} from "@openzeppelin/confidential-contracts/token/ConfidentialFungibleToken.sol";
import {
    ConfidentialFungibleTokenUtils
} from "@openzeppelin/confidential-contracts/token/utils/ConfidentialFungibleTokenUtils.sol";
import {
    IConfidentialFungibleToken
} from "@openzeppelin/confidential-contracts/interfaces/IConfidentialFungibleToken.sol";
import {SepoliaConfig} from "@fhevm/solidity/config/ZamaConfig.sol";
import {SafeTransfer} from "./SafeTransfer.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

interface IWeth {
    event Approval(address indexed src, address indexed guy, uint wad);
    event Transfer(address indexed src, address indexed dst, uint wad);
    event Deposit(address indexed dst, uint wad);
    event Withdrawal(address indexed src, uint wad);

    function deposit() external payable;

    function withdraw(uint wad) external;

    function transferFrom(address src, address dst, uint wad) external returns (bool);

    function transfer(address dst, uint wad) external returns (bool);

    function totalSupply() external view returns (uint);

    function approve(address guy, uint wad) external returns (bool);
}

/**
 * @title  ConfWrap
 * @notice This contract governs the pair created in the AMM, minting of liquidity of a ERC20 to ERC7984 pair,
 * at fixed rate of 1, i.e. 1 WETH = 1 ERC7984 token.
 * Based on the ConfidentialFungibleTokenERC20Wrapper
 *
 * @dev At the moment, we limit the contract to a WETH/CWETH(Confidential WETH) wrap and unwrapping
 * For creating ERC20/ERC7984 pairs, use the ConfidentialFungibleTokenERC20Wrapper
 */
abstract contract ConfWrapper is ConfidentialFungibleToken {
    uint256 private immutable _rate;
    IWeth private immutable _baseToken;

    /// @dev Mapping from gateway decryption request ID to the address that will receive the tokens
    mapping(uint256 decryptionRequest => address) private _receivers;

    constructor(IWeth baseToken, uint256 rate) {
        _rate = rate;
        _baseToken = baseToken;
    }

    /**
     * @dev Returns the rate at which the underlying token is converted to the wrapped token.
     * For example, if the `rate` is 1000, then 1000 units of the underlying token equal 1 unit of the wrapped token.
     */
    function rate() public view virtual returns (uint256) {
        return _rate;
    }

    /// @notice At the moment we only operate on Weth
    /// @dev Returns the address of the underlying token that is being wrapped.
    function underlying() public view returns (IWeth) {
        return _baseToken;
    }

    /**
     * @dev Wraps amount `amount` of the underlying token into a confidential token and sends it to
     * `to`. Tokens are exchanged at a fixed rate specified by {rate} such that `amount / rate()` confidential
     * tokens are sent. Amount transferred in is rounded down to the nearest multiple of {rate}.
     */
    function wrap(address to, uint256 amount) public virtual {
        // take ownership of the tokens
        SafeTransfer.safeTransferFrom(underlying(), msg.sender, address(this), amount - (amount % rate()));

        // mint confidential token
        _mint(to, FHE.asEuint64(SafeCast.toUint64(amount / rate())));
    }

    /**
     * @dev Unwraps tokens from `from` and sends the underlying tokens to `to`. The caller must be `from`
     * or be an approved operator for `from`. `amount * rate()` underlying tokens are sent to `to`.
     *
     * NOTE: This is an asynchronous function and waits for decryption to be completed off-chain before disbursing
     * tokens.
     * NOTE: The caller *must* already be approved by ACL for the given `amount`.
     */
    function unwrap(address from, address to, euint64 amount) public virtual {
        require(
            FHE.isAllowed(amount, msg.sender),
            ConfidentialFungibleTokenUnauthorizedUseOfEncryptedAmount(amount, msg.sender)
        );
        _unwrap(from, to, amount);
    }

    /**
     * @dev Variant of {unwrap} that passes an `inputProof` which approves the caller for the `encryptedAmount`
     * in the ACL.
     */
    function unwrap(
        address from,
        address to,
        externalEuint64 encryptedAmount,
        bytes calldata inputProof
    ) public virtual {
        _unwrap(from, to, FHE.fromExternal(encryptedAmount, inputProof));
    }

    /**
     * @dev Fills an unwrap request for a given request id related to a decrypted unwrap amount.
     */
    function finalizeUnwrap(
        uint256 requestID,
        bytes calldata cleartexts,
        bytes calldata decryptionProof
    ) public virtual {
        FHE.checkSignatures(requestID, cleartexts, decryptionProof);
        uint64 amount = abi.decode(cleartexts, (uint64));
        address to = _receivers[requestID];
        require(to != address(0), ConfidentialFungibleTokenInvalidGatewayRequest(requestID));
        delete _receivers[requestID];

        SafeTransfer.safeTransfer(underlying(), to, amount * rate());
    }

    function _unwrap(address from, address to, euint64 amount) internal virtual {
        require(to != address(0), ConfidentialFungibleTokenInvalidReceiver(to));
        require(
            from == msg.sender || isOperator(from, msg.sender),
            ConfidentialFungibleTokenUnauthorizedSpender(from, msg.sender)
        );

        // try to burn, see how much we actually got
        euint64 burntAmount = _burn(from, amount);

        // decrypt that burntAmount
        bytes32[] memory cts = new bytes32[](1);
        cts[0] = euint64.unwrap(burntAmount);
        uint256 requestID = FHE.requestDecryption(cts, this.finalizeUnwrap.selector);

        // register who is getting the tokens
        _receivers[requestID] = to;
    }
}

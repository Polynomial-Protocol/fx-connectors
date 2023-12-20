// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {Initializable} from "../proxy/utils/Initializable.sol";
import {AuthUpgradable, Authority} from "../libraries/AuthUpgradable.sol";
import {ReentrancyGuardUpgradable} from "../libraries/ReentracyUpgradable.sol";

interface IAccount {
    function cast(string[] calldata _targetNames, bytes[] calldata _datas, address _origin) external;
    function isAuth(address user) external view returns (bool);
}

interface IList {
    function accountID(address) external view returns (uint64);
}

contract SynthetixLimitOrdersV3 is Initializable, AuthUpgradable, ReentrancyGuardUpgradable {
    /// -----------------------------------------------------------------------
    /// Library usage
    /// -----------------------------------------------------------------------
    using FixedPointMathLib for uint256;

    /// -----------------------------------------------------------------------
    /// Data Types
    /// -----------------------------------------------------------------------

    struct EIP712Domain {
        string name;
        string version;
        uint256 chainId;
        address verifyingContract;
    }

    struct PriceRange {
        uint256 priceA;
        uint256 priceB;
        uint256 acceptablePrice;
    }

    struct OrderRequest {
        address user;
        PriceRange price;
        PriceRange tpPrice;
        PriceRange slPrice;
        uint128 accountId;
        uint128 marketId;
        int128 size;
        uint128 expiry;
    }

    bytes32 constant EIP712DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    bytes32 constant PRICE_RANGE_TYPEHASH =
        keccak256("PriceRange(uint256 priceA,uint256 priceB,uint256 acceptablePrice)");

    bytes32 constant ORDER_REQUEST_TYPEHASH = keccak256(
        "OrderRequest(address user,PriceRange price,PriceRange tpPrice,PriceRange slPrice,uint128 accountId,uint128 marketId,int128 size,uint128 expiry)"
    );

    /// -----------------------------------------------------------------------
    /// Storage
    /// -----------------------------------------------------------------------

    /// @notice SCW Index List
    IList public list;

    /// @notice Domain Separator for EIP-712
    bytes32 public DOMAIN_SEPARATOR;

    /// @notice Next order id
    uint256 public nextOrderId;

    /// @notice Storage gap
    uint256[50] private _gap;

    /// @notice Initializer
    function initialize(address _list) public initializer {
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                EIP712DOMAIN_TYPEHASH,
                keccak256(bytes("Polynomial Limit Orders")),
                keccak256(bytes("3")),
                block.chainid,
                msg.sender
            )
        );
        nextOrderId = 1;
        list = IList(_list);
    }

    function executeOrder(OrderRequest memory req, bytes memory sig) public nonReentrant {
        address signer = getSigner(req, sig);

        if (list.accountID(req.user) == 0) {
            revert NotScw(req.user);
        }

        IAccount account = IAccount(req.user);

        if (!account.isAuth(signer)) {
            revert NotAuth(signer);
        }
    }

    /// -----------------------------------------------------------------------
    /// Internals
    /// -----------------------------------------------------------------------

    /**
     * @dev Split signature
     * @param _sig Signature that needs to be split into v, r, s
     */
    function splitSignature(bytes memory _sig) internal pure returns (uint8, bytes32, bytes32) {
        require(_sig.length == 65);

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            // first 32 bytes, after the length prefix
            r := mload(add(_sig, 32))
            // second 32 bytes
            s := mload(add(_sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(_sig, 96)))
        }

        return (v, r, s);
    }

    /**
     * @dev Get signer from signature
     * @param _req Corresponsding order request
     * @param _sig Signature
     */
    function getSigner(OrderRequest memory _req, bytes memory _sig) internal view returns (address) {
        bytes32 priceHash = keccak256(
            abi.encode(PRICE_RANGE_TYPEHASH, _req.price.priceA, _req.price.priceB, _req.price.acceptablePrice)
        );
        bytes32 tpPriceHash = keccak256(
            abi.encode(PRICE_RANGE_TYPEHASH, _req.tpPrice.priceA, _req.tpPrice.priceB, _req.tpPrice.acceptablePrice)
        );
        bytes32 slPriceHash = keccak256(
            abi.encode(PRICE_RANGE_TYPEHASH, _req.slPrice.priceA, _req.slPrice.priceB, _req.slPrice.acceptablePrice)
        );
        bytes32 reqHash = keccak256(
            abi.encode(
                ORDER_REQUEST_TYPEHASH,
                _req.user,
                priceHash,
                tpPriceHash,
                slPriceHash,
                _req.accountId,
                _req.marketId,
                _req.size,
                _req.expiry
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, reqHash));
        (uint8 v, bytes32 r, bytes32 s) = splitSignature(_sig);
        return ecrecover(digest, v, r, s);
    }

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    /**
     * @dev Not Smart wallet error
     * @param user Address of the requested user
     */
    error NotScw(address user);

    /**
     * @dev Unauthorized signature
     * @param signer Address of the signer
     */
    error NotAuth(address signer);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Auth, Authority} from "solmate/auth/Auth.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

interface IAccount {
    function cast(string[] calldata _targetNames, bytes[] calldata _datas, address _origin) external;
}

interface IList {
    function accountID(address) external view returns (uint64);
}

interface IPerpMarket {
    function assetPrice() external view returns (uint256 price, bool invalid);
}

contract SynthetixSmartMargin is Auth, ReentrancyGuard {
    /// -----------------------------------------------------------------------
    /// Library usage
    /// -----------------------------------------------------------------------
    using FixedPointMathLib for uint256;

    /// -----------------------------------------------------------------------
    /// State Variables
    /// -----------------------------------------------------------------------

    /// @notice Fee per each order
    uint256 public perOrderFee;

    /// @notice Fee receipient
    address public feeReceipient;

    constructor() Auth(msg.sender, Authority(address(0x0))) {}

    /// -----------------------------------------------------------------------
    /// User Actions
    /// -----------------------------------------------------------------------

    function distributeEqually(
        address[] memory markets,
        int256[] memory sizeDeltas,
        uint256[] memory priceImpactDeltas,
        uint256 totalMargin
    ) external nonReentrant {
        require(isAllowed());
        require(markets.length == sizeDeltas.length);

        uint256 totalNotionalSize;
        uint256[] memory notionalValues = new uint256[](markets.length);

        for (uint256 i = 0; i < markets.length; i++) {
            (uint256 assetPrice, bool invalid) = IPerpMarket(markets[i]).assetPrice();
            require(!invalid);
            uint256 absSize = _abs(sizeDeltas[i]);

            uint256 notionalValue = absSize.mulWadDown(assetPrice);

            totalNotionalSize += notionalValue;

            notionalValues[i] = notionalValue;
        }

        uint256 fees = totalNotionalSize.mulWadDown(perOrderFee);
        totalMargin -= fees;

        uint256 actionsLength = 2 * markets.length + 1;

        string[] memory targets = new string[](actionsLength);
        bytes[] memory datas = new bytes[](actionsLength);

        for (uint256 i = 0; i < markets.length; i++) {
            uint256 marginForMarket = notionalValues[i].mulDivDown(totalMargin, totalNotionalSize);

            targets[2 * i] = "Synthetix-Perp-v1";
            targets[2 * i + 1] = "Synthetix-Perp-v1";

            datas[2 * i] =
                abi.encodeWithSignature("addMargin(address,uint256,uint256,uint256)", markets[i], marginForMarket, 0, 0);
            datas[2 * i + 1] = abi.encodeWithSignature(
                "trade(address,int256,uint256)", markets[i], sizeDeltas[i], priceImpactDeltas[i]
            );
        }

        targets[actionsLength - 1] = "Basic-v1";
        datas[actionsLength - 1] = abi.encodeWithSignature(
            "withdraw(address,uint256,address,uint256,uint256)",
            0x8c6f28f2F1A3C87F0f938b96d27520d9751ec8d9,
            fees,
            feeReceipient,
            0,
            0
        );

        IAccount(msg.sender).cast(targets, datas, address(0x0));

        emit DistributeEqually(msg.sender, markets, sizeDeltas, priceImpactDeltas, fees, totalMargin);
    }

    /// -----------------------------------------------------------------------
    /// Internals
    /// -----------------------------------------------------------------------

    /// @notice Returns whether an address is a SCW or not
    function isAllowed() internal view returns (bool) {
        return IList(0xd567E18FDF8aFa58953DD8B0c1b6C97adF67566B).accountID(msg.sender) != 0;
    }

    function _signedAbs(int256 x) internal pure returns (int256) {
        return x < 0 ? -x : x;
    }

    function _abs(int256 x) internal pure returns (uint256) {
        return uint256(_signedAbs(x));
    }

    /// -----------------------------------------------------------------------
    /// Admin Actions
    /// -----------------------------------------------------------------------

    /// @notice Update fees
    /// @param _perOrderFee New fee
    function updateFees(uint256 _perOrderFee) external requiresAuth {
        emit UpdateFees(perOrderFee, _perOrderFee);

        perOrderFee = _perOrderFee;
    }

    function updateFeeReceipient(address _feeReceipeint) external requiresAuth {
        emit UpdateFeeReceipient(feeReceipient, _feeReceipeint);

        feeReceipient = _feeReceipeint;
    }

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event UpdateFees(uint256 oldFee, uint256 newFee);
    event UpdateFeeReceipient(address oldFeeReceipient, address newFeeReceipient);
    event DistributeEqually(
        address indexed wallet,
        address[] markets,
        int256[] sizes,
        uint256[] priceImpacts,
        uint256 totalFees,
        uint256 marginAdded
    );
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IPerpMarket {
    function postTradeDetails(int256 sizeDelta, uint256 tradePrice, uint8 orderType, address sender)
        external
        view
        returns (uint256 margin, int256 size, uint256 price, uint256 liqPrice, uint256 fee, uint8 status);

    function accessibleMargin(address account) external view returns (uint256 marginAccessible, bool invalid);
}

interface IDynamicKeeperFeeModule {
    function getMinKeeperFee() external view returns (uint256);
}

contract DragonFruit {
    IDynamicKeeperFeeModule private constant dynamicKeeperFee =
        IDynamicKeeperFeeModule(0x05F6f46e5EED6dec1D8Cc3c6e8169D447966844d);

    function calculate(address market, int256 sizeDelta, address account, uint256 executionPrice)
        external
        view
        returns (
            uint256 minKeeperFee,
            uint256 fee,
            uint256 liquidationPrice,
            uint256 totalMargin,
            uint256 accessibleMargin,
            uint256 assetPrice,
            uint8 status
        )
    {
        minKeeperFee = dynamicKeeperFee.getMinKeeperFee();
        IPerpMarket perpMarket = IPerpMarket(market);

        (totalMargin,, assetPrice, liquidationPrice, fee, status) =
            perpMarket.postTradeDetails(sizeDelta, executionPrice, 2, account);

        (accessibleMargin,) = perpMarket.accessibleMargin(account);
    }
}

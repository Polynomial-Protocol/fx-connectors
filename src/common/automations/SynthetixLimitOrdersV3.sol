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

interface IPyth {
    function getUpdateFee(bytes[] memory) external view returns (uint256);
}

interface IPythNode {
    function pythAddress() external view returns (IPyth);
    function fulfillOracleQuery(bytes memory signedOffchainData) external payable;
    function getLatestPrice(bytes32 priceId, uint256 stalenessTolerance) external view returns (int256);
}

interface IPerpMarket {
    function getOpenPosition(uint128 accountId, uint128 marketId)
        external
        view
        returns (int256 pnl, int256 accruedFunding, int128 positionSize);
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

    enum OrderStatus {
        SUBMITTED,
        EXECUTED,
        COMPLETED,
        CANCELLED
    }

    enum ExecutionType {
        LIMIT_ORDER,
        STOP_LOSS,
        TAKE_PROFIT
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

    /// @notice Pyth Node
    IPythNode public pythNode;

    /// @notice Perp Market
    IPerpMarket public perpMarket;

    /// @notice Domain Separator for EIP-712
    bytes32 public DOMAIN_SEPARATOR;

    /// @notice Next order id
    uint256 public nextOrderId;

    /// @notice Storage gap
    uint256[50] private _gap;

    /// @notice Orders
    mapping(uint256 => OrderRequest) public orders;

    /// @notice Order status
    mapping(uint256 => OrderStatus) public status;

    /// @notice Cancelled hashes
    mapping(bytes32 => bool) public cancelledHashes;

    /// @notice Submitted hashes
    mapping(bytes32 => bool) public submittedHashes;

    mapping(uint128 => bytes32) public priceIds;

    /// @notice Initializer
    function initialize(address _owner, address _list, address _pythNode, address _perpMarket) public initializer {
        _auth_init(_owner, Authority(address(0x0)));
        _reentrancy_init();

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
        pythNode = IPythNode(_pythNode);
        perpMarket = IPerpMarket(_perpMarket);
    }

    /**
     * @notice Place the order on-chain
     * @param req Order request
     */
    function placeOrder(OrderRequest memory req) external onlyScw {
        uint256 orderId = nextOrderId++;
        orders[orderId] = req;

        if (req.user != msg.sender) {
            revert NotAuthorized(req.user, msg.sender);
        }

        if (!_isPriceValid(req.price)) {
            status[orderId] = OrderStatus.EXECUTED;
        }

        emit OrderPlaced(req.user, req.marketId, orderId, req, "");
    }

    /**
     * @notice Execute main limit order
     * @param req Order request
     * @param sig User signed message of the request
     */
    function executeOrder(OrderRequest memory req, bytes memory sig) external nonReentrant {
        if (!_isPriceValid(req.price)) {
            revert InvalidPriceRange(req.price);
        }

        if (req.size == 0) {
            revert OrderSizeZero();
        }

        if (block.timestamp > req.expiry) {
            revert OrderExpired(req.expiry, block.timestamp);
        }

        bytes32 digest = keccak256(sig);

        if (cancelledHashes[digest]) {
            revert SignatureCancelled(digest);
        }

        if (submittedHashes[digest]) {
            revert SignatureSubmitted(digest);
        }

        _placeOrder(req, sig);

        (bool isValid, uint256 currentPrice) = _isOrderValid(req.marketId, req.price);

        if (!isValid) {
            revert PriceNotInRange(req.price.priceA, req.price.priceB, currentPrice);
        }

        _castSpells(nextOrderId - 1, req, ExecutionType.LIMIT_ORDER, currentPrice);
    }

    /**
     * @notice Execute main limit order (on-chain)
     * @param orderId Order ID
     */
    function executeOrder(uint256 orderId) external nonReentrant {
        OrderRequest memory order = orders[orderId];

        if (block.timestamp > order.expiry) {
            revert OrderExpired(order.expiry, block.timestamp);
        }

        if (status[orderId] == OrderStatus.CANCELLED) {
            revert OrderCancelled(orderId);
        }

        if (status[orderId] == OrderStatus.EXECUTED) {
            revert OrderExecuted(orderId);
        }

        if (status[orderId] == OrderStatus.COMPLETED) {
            revert OrderCompleted(orderId);
        }

        if (order.size == 0) {
            revert OrderSizeZero();
        }

        (bool isValid, uint256 currentPrice) = _isOrderValid(order.marketId, order.price);

        if (!isValid) {
            revert PriceNotInRange(order.price.priceA, order.price.priceB, currentPrice);
        }

        _castSpells(orderId, order, ExecutionType.LIMIT_ORDER, currentPrice);
    }

    /**
     * @notice Execute TP limit order
     * @param req Order request
     * @param sig User signed message of the request
     */
    function executeTpOrder(OrderRequest memory req, bytes memory sig) external nonReentrant {
        if (!_isPriceValid(req.tpPrice)) {
            revert InvalidPriceRange(req.tpPrice);
        }

        if (_isPriceValid(req.price)) {
            revert OrderNotExecuted(0);
        }

        if (req.size == 0) {
            revert OrderSizeZero();
        }

        if (block.timestamp > req.expiry) {
            revert OrderExpired(req.expiry, block.timestamp);
        }

        bytes32 digest = keccak256(sig);

        if (cancelledHashes[digest]) {
            revert SignatureCancelled(digest);
        }

        if (submittedHashes[digest]) {
            revert SignatureSubmitted(digest);
        }

        _placeOrder(req, sig);

        (bool isValid, uint256 currentPrice) = _isOrderValid(req.marketId, req.tpPrice);

        if (!isValid) {
            revert PriceNotInRange(req.tpPrice.priceA, req.tpPrice.priceB, currentPrice);
        }

        _castSpells(nextOrderId - 1, req, ExecutionType.TAKE_PROFIT, currentPrice);
    }

    /**
     * @notice Execute TP limit order
     * @param orderId Order ID
     */
    function executeTpOrder(uint256 orderId) external nonReentrant {
        OrderRequest memory order = orders[orderId];

        if (block.timestamp > order.expiry) {
            revert OrderExpired(order.expiry, block.timestamp);
        }

        if (status[orderId] == OrderStatus.CANCELLED) {
            revert OrderCancelled(orderId);
        }

        if (status[orderId] == OrderStatus.SUBMITTED) {
            revert OrderNotExecuted(orderId);
        }

        if (status[orderId] == OrderStatus.COMPLETED) {
            revert OrderCompleted(orderId);
        }

        if (!_isPriceValid(order.tpPrice)) {
            revert InvalidPriceRange(order.tpPrice);
        }

        (bool isValid, uint256 currentPrice) = _isOrderValid(order.marketId, order.tpPrice);

        if (!isValid) {
            revert PriceNotInRange(order.tpPrice.priceA, order.tpPrice.priceB, currentPrice);
        }

        _castSpells(orderId, order, ExecutionType.TAKE_PROFIT, currentPrice);
    }

    /**
     * @notice Execute SOL limit order
     * @param req Order request
     * @param sig User signed message of the request
     */
    function executeSlOrder(OrderRequest memory req, bytes memory sig) external nonReentrant {
        if (!_isPriceValid(req.slPrice)) {
            revert InvalidPriceRange(req.slPrice);
        }

        if (_isPriceValid(req.price)) {
            revert OrderNotExecuted(0);
        }

        if (req.size == 0) {
            revert OrderSizeZero();
        }

        if (block.timestamp > req.expiry) {
            revert OrderExpired(req.expiry, block.timestamp);
        }

        bytes32 digest = keccak256(sig);

        if (cancelledHashes[digest]) {
            revert SignatureCancelled(digest);
        }

        if (submittedHashes[digest]) {
            revert SignatureSubmitted(digest);
        }

        _placeOrder(req, sig);

        (bool isValid, uint256 currentPrice) = _isOrderValid(req.marketId, req.slPrice);

        if (!isValid) {
            revert PriceNotInRange(req.slPrice.priceA, req.slPrice.priceB, currentPrice);
        }

        _castSpells(nextOrderId - 1, req, ExecutionType.STOP_LOSS, currentPrice);
    }

    /**
     * @notice Execute SL limit order
     * @param orderId Order ID
     */
    function executeSlOrder(uint256 orderId) external nonReentrant {
        OrderRequest memory order = orders[orderId];

        if (block.timestamp > order.expiry) {
            revert OrderExpired(order.expiry, block.timestamp);
        }

        if (status[orderId] == OrderStatus.CANCELLED) {
            revert OrderCancelled(orderId);
        }

        if (status[orderId] == OrderStatus.SUBMITTED) {
            revert OrderNotExecuted(orderId);
        }

        if (status[orderId] == OrderStatus.COMPLETED) {
            revert OrderCompleted(orderId);
        }

        if (!_isPriceValid(order.slPrice)) {
            revert InvalidPriceRange(order.slPrice);
        }

        (bool isValid, uint256 currentPrice) = _isOrderValid(order.marketId, order.slPrice);

        if (!isValid) {
            revert PriceNotInRange(order.slPrice.priceA, order.slPrice.priceB, currentPrice);
        }

        _castSpells(orderId, order, ExecutionType.STOP_LOSS, currentPrice);
    }

    /**
     * @notice Cancel off chain order
     * @param sig Off-chain signature
     */
    function cancelOrder(OrderRequest memory req, bytes memory sig) external {
        bytes32 digest = keccak256(sig);

        address signer = _getSigner(req, sig);
        if (msg.sender != signer && msg.sender != req.user) {
            revert NotAuthorized(signer, msg.sender);
        }

        cancelledHashes[digest] = true;

        emit OrderCancel(sig);
    }

    /**
     * @notice Cancel Order
     * @param id Order ID
     */
    function cancelOrder(uint256 id) external {
        OrderRequest memory order = orders[id];

        if (msg.sender != order.user) {
            revert NotAuthorized(order.user, msg.sender);
        }

        status[id] = OrderStatus.CANCELLED;

        emit OrderCancel(order.user, order.marketId, id);
    }

    /**
     * @notice Update Pyth oracle via Synthetix wrapper
     * @param signedOffchainData Signed offchain data
     */
    function updateOracle(bytes memory signedOffchainData) external payable {
        _updateOracle(signedOffchainData);
    }

    /**
     * @notice Call multiple functions in the current contract and return the data from all of them if they all succeed
     * @dev The `msg.value` should not be trusted for any method callable from multicall.
     * @param data The encoded function data for each of the calls to make to this contract
     * @return results The results from each of the calls passed in via data
     */
    function multicall(bytes[] calldata data) public payable returns (bytes[] memory results) {
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(data[i]);

            if (!success) {
                // Next 5 lines from https://ethereum.stackexchange.com/a/83577
                if (result.length < 68) revert();
                assembly {
                    result := add(result, 0x04)
                }
                revert(abi.decode(result, (string)));
            }

            results[i] = result;
        }
    }

    /// -----------------------------------------------------------------------
    /// Admin methods
    /// -----------------------------------------------------------------------

    function updatePriceIds(uint128[] memory _marketIds, bytes32[] memory _priceIds) external requiresAuth {
        if (_marketIds.length != _priceIds.length) {
            revert LengthMismatch();
        }

        for (uint256 i = 0; i < _marketIds.length; i++) {
            emit UpdatePriceId(_marketIds[i], priceIds[_marketIds[i]], _priceIds[i]);
            priceIds[_marketIds[i]] = _priceIds[i];
        }
    }

    function sweep() external requiresAuth {
        (bool success,) = msg.sender.call{value: address(this).balance}("");
        require(success);
    }

    /// -----------------------------------------------------------------------
    /// Internals
    /// -----------------------------------------------------------------------

    /**
     * @notice Generate spells to cast
     * @param req Order request
     * @param execType Type of order to execute
     */
    function _castSpells(uint256 orderId, OrderRequest memory req, ExecutionType execType, uint256 currentPrice)
        internal
    {
        string[] memory targetNames = new string[](1);
        bytes[] memory datas = new bytes[](1);

        targetNames[0] = "Synthetix-Perp-v3-v1.2";

        if (execType == ExecutionType.LIMIT_ORDER) {
            datas[0] = abi.encodeWithSignature(
                "commitTrade(uint128,uint128,int128,uint256)",
                req.accountId,
                req.marketId,
                req.size,
                req.price.acceptablePrice
            );

            status[orderId] = (_isPriceValid(req.tpPrice) || _isPriceValid(req.slPrice))
                ? OrderStatus.EXECUTED
                : OrderStatus.COMPLETED;
        } else {
            (,, int128 currentPosition) = perpMarket.getOpenPosition(req.accountId, req.marketId);

            (bool compatible, int128 sizeDelta) = _checkAndGetTpSlDelta(req.size, currentPosition);
            if (!compatible) {
                revert PositionChangedDirection(req.size, currentPosition);
            }

            uint256 acceptablePrice =
                execType == ExecutionType.STOP_LOSS ? req.slPrice.acceptablePrice : req.tpPrice.acceptablePrice;

            datas[0] = abi.encodeWithSignature(
                "commitTrade(uint128,uint128,int128,uint256)", req.accountId, req.marketId, sizeDelta, acceptablePrice
            );

            status[orderId] = OrderStatus.COMPLETED;
        }

        IAccount(req.user).cast(targetNames, datas, address(this));

        emit OrderExec(req.user, req.marketId, orderId, execType, currentPrice, 0);
    }

    /**
     * @notice Validate order and push to storage
     * @param req Order request
     * @param sig User signed message of the request
     */
    function _placeOrder(OrderRequest memory req, bytes memory sig) internal {
        address signer = _getSigner(req, sig);

        if (list.accountID(req.user) == 0) {
            revert NotScw(req.user);
        }

        IAccount account = IAccount(req.user);

        if (!account.isAuth(signer)) {
            revert NotAuth(signer);
        }

        orders[nextOrderId++] = req;
        bytes32 digest = keccak256(sig);

        submittedHashes[digest] = true;
        emit OrderPlaced(req.user, req.marketId, nextOrderId - 1, req, digest);
    }

    /**
     * @notice Update pyth oracle via Synthetix wrapper
     * @param signedOffchainData signed offchain data
     */
    function _updateOracle(bytes memory signedOffchainData) internal {
        (,,, bytes[] memory updateData) = abi.decode(signedOffchainData, (uint8, uint64, bytes32[], bytes[]));

        IPyth pyth = pythNode.pythAddress();
        uint256 updateFee = pyth.getUpdateFee(updateData);

        if (msg.value < updateFee) {
            revert InsufficientFee(updateFee, msg.value);
        }

        pythNode.fulfillOracleQuery{value: updateFee}(signedOffchainData);
    }

    /**
     * @notice Checks whether the price range is valid to execute now
     * @param marketId Market ID
     * @param range Price range
     */
    function _isOrderValid(uint128 marketId, PriceRange memory range) internal view returns (bool, uint256) {
        bytes32 priceId = priceIds[marketId];
        uint256 currentPrice = uint256(pythNode.getLatestPrice(priceId, 0));

        return (currentPrice >= range.priceA && currentPrice <= range.priceB, currentPrice);
    }

    /**
     * @dev Split signature
     * @param _sig Signature that needs to be split into v, r, s
     */
    function _splitSignature(bytes memory _sig) internal pure returns (uint8, bytes32, bytes32) {
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
    function _getSigner(OrderRequest memory _req, bytes memory _sig) internal view returns (address) {
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
        (uint8 v, bytes32 r, bytes32 s) = _splitSignature(_sig);
        return ecrecover(digest, v, r, s);
    }

    /**
     * @notice Returns whether the price range is valid or not
     * @param price price range object
     */
    function _isPriceValid(PriceRange memory price) internal pure returns (bool) {
        if (price.priceA == 0 || price.priceB == 0) {
            return false;
        }

        if (price.priceA > price.priceB) {
            return false;
        }

        return true;
    }

    function _checkAndGetTpSlDelta(int128 requestSize, int128 openPosition)
        internal
        pure
        returns (bool compatible, int128 sizeDelta)
    {
        if (!_sameSign(requestSize, openPosition)) {
            compatible = false;
            return (compatible, sizeDelta);
        }

        compatible = true;
        sizeDelta = (_signedAbs(requestSize) > _signedAbs(openPosition)) ? -openPosition : -requestSize;
    }

    function _signedAbs(int128 x) internal pure returns (int128) {
        return x < 0 ? -x : x;
    }

    function _sameSign(int128 a, int128 b) internal pure returns (bool) {
        return (a != 0) && (b != 0) && (a > 0) == (b > 0);
    }

    /// -----------------------------------------------------------------------
    /// Modifiers
    /// -----------------------------------------------------------------------

    modifier onlyScw() {
        if (list.accountID(msg.sender) == 0) {
            revert NotScw(msg.sender);
        }
        _;
    }

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    /**
     * @notice Not Smart wallet error
     * @param user Address of the requested user
     */
    error NotScw(address user);

    /**
     * @notice Not auth of SCW
     * @param signer Address of the signer
     */
    error NotAuth(address signer);

    /**
     * @notice Unauthorized
     * @param user Address of the user (SCW)
     * @param sender Address of the tx sender
     */
    error NotAuthorized(address user, address sender);

    /**
     * @notice Invalid price range error
     * @param price Price range
     */
    error InvalidPriceRange(PriceRange price);

    /**
     * @notice Insufficient fee
     * @param required Required fee
     * @param fee Paid fee
     */
    error InsufficientFee(uint256 required, uint256 fee);

    /**
     * @notice Executing cancelled order
     * @param digest keccak256 of signature
     */
    error SignatureCancelled(bytes32 digest);

    /**
     * @notice Executing cancelled order
     * @param orderId ID of the order
     */
    error OrderCancelled(uint256 orderId);

    /**
     * @notice Resubmitting signature
     * @param digest keccak256 of signature
     */
    error SignatureSubmitted(bytes32 digest);

    /**
     * @notice Order already executed
     * @param orderId ID of the order
     */
    error OrderExecuted(uint256 orderId);

    /**
     * @notice Order not executed (trying to execute TP/SL direct)
     * @param orderId ID of the order
     */
    error OrderNotExecuted(uint256 orderId);

    /**
     * @notice Order already completed
     * @param orderId ID of the order
     */
    error OrderCompleted(uint256 orderId);

    /**
     * @notice Error when the price is not in range to execute the order
     * @param priceA Price A
     * @param priceB Price B
     * @param currentPrice Current price
     */
    error PriceNotInRange(uint256 priceA, uint256 priceB, uint256 currentPrice);

    /**
     * @notice Error when position direction and requestsize direction do not match in tp/sl
     * @param requestSize requestSize
     * @param position position
     */
    error PositionChangedDirection(int128 requestSize, int128 position);

    /**
     * @notice Error when order's expiry timestamp has passed
     * @param orderExpiry order.expiry
     * @param blockTimestamp block.timestamp
     */
    error OrderExpired(uint256 orderExpiry, uint256 blockTimestamp);

    /**
     * @notice Error when order size is 0
     */
    error OrderSizeZero();

    /**
     * @notice Length mismatch error
     */
    error LengthMismatch();

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    /**
     * @notice Emitted when the order is pushed on-chain
     * @param user Address of the user (SCW)
     * @param marketId Market ID
     * @param orderId Order ID
     * @param req Order request
     */
    event OrderPlaced(
        address indexed user, uint128 indexed marketId, uint256 orderId, OrderRequest req, bytes32 digest
    );

    /**
     * @notice Emitted when the order is executed
     * @param user Address of the user (SCW)
     * @param marketId Market ID
     * @param orderId Order ID
     * @param execType Order request
     * @param executionPrice price of asset during execution
     * @param totalFee total fee from this execution
     */
    event OrderExec(
        address indexed user,
        uint128 indexed marketId,
        uint256 orderId,
        ExecutionType execType,
        uint256 executionPrice,
        uint256 totalFee
    );

    /**
     * @notice Emitted when the order is cancelled
     * @param user Address of the user (SCW)
     * @param marketId Market ID
     * @param orderId Order ID
     */
    event OrderCancel(address indexed user, uint128 indexed marketId, uint256 orderId);

    /**
     * @notice Emitted when the order is cancelled
     * @param sig Signature of the order
     */
    event OrderCancel(bytes sig);

    /**
     * @notice Emitted when price id is updated
     * @param marketId Market ID
     * @param oldId Old price ID
     * @param newId New price ID
     */
    event UpdatePriceId(uint128 indexed marketId, bytes32 oldId, bytes32 newId);
}

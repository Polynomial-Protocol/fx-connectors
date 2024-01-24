// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {Initializable} from "../proxy/utils/Initializable.sol";
import {AuthUpgradable, Authority} from "../libraries/AuthUpgradable.sol";
import {ReentrancyGuardUpgradable} from "../libraries/ReentracyUpgradable.sol";

import {IList, IPythNode, IPyth, IPerpMarket, IAccount} from "./SynthetixLimitOrdersV3.sol";

contract SynthetixTwapOrdersV3 is Initializable, AuthUpgradable, ReentrancyGuardUpgradable {
    /// -----------------------------------------------------------------------
    /// Library usage
    /// -----------------------------------------------------------------------
    using FixedPointMathLib for uint256;

    /// -----------------------------------------------------------------------
    /// Data Types
    /// -----------------------------------------------------------------------

    struct OrderRequest {
        address user; // scw address
        uint128 accountId;
        uint128 marketId;
        int128 lotSize; // Size of each order
        uint128 startTime; // 0 if on-chain order that starts now; actual start timestamp otherwise (offchain sig)
        uint128 interval; // Interval between each order
        uint128 totalIterations; // Total iterations
        uint128 acceptableDeviation; // Acceptal deviation for interval
        uint128 slippage; // Calculate acceptable price from slippage and current price for v3
    }

    enum OrderStatus {
        EXECUTING,
        COMPLETED,
        CANCELLED
    }

    struct OrderRecord {
        OrderStatus status;
        uint256 lastExecutionTimestamp;
        uint128 iterationsCompleted;
    }

    bytes32 constant EIP712DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    bytes32 constant ORDER_REQUEST_TYPEHASH = keccak256(
        "OrderRequest(address user,uint128 accountId,uint128 marketId,int128 lotSize,uint128 startTime,uint128 interval,uint128 totalIterations,uint128 acceptableDeviation,uint128 slippage)"
    );

    uint256 public constant WAD = 1e18;

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

    /// @notice Order records
    mapping(uint256 => OrderRecord) public records;

    /// @notice Cancelled hashes
    mapping(bytes32 => bool) public cancelledHashes;

    /// @notice Submitted hashes
    mapping(bytes32 => bool) public submittedHashes;

    /// @notice market id to pythnode price id mapping
    mapping(uint128 => bytes32) public priceIds;

    /// -----------------------------------------------------------------------
    /// Functions
    /// -----------------------------------------------------------------------

    /// @notice Initializer
    function initialize(address _owner, address _list, address _pythNode, address _perpMarket) public initializer {
        _auth_init(_owner, Authority(address(0x0)));
        _reentrancy_init();

        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                EIP712DOMAIN_TYPEHASH,
                keccak256(bytes("Polynomial Twap Orders")),
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
     * @notice Place the order on-chain that starts now
     * @param req Order request
     */
    function placeOrder(OrderRequest memory req) external onlyScw nonReentrant {
        if (req.startTime != 0) {
            revert InvalidOrder(req);
        }

        if (req.totalIterations == 0) {
            revert InvalidOrder(req);
        }

        uint256 orderId = nextOrderId++;
        orders[orderId] = req;

        _castSpells(orderId, req);
    }

    /**
     * @notice Execute twap order(off-chain)
     * @param req order request
     * @param sig User signed message of the request
     */
    function executeOrder(OrderRequest memory req, bytes memory sig) external nonReentrant {
        if (req.totalIterations == 0) {
            revert InvalidOrder(req);
        }

        bytes32 digest = keccak256(sig);

        if (cancelledHashes[digest]) {
            revert SignatureCancelled(digest);
        }

        if (submittedHashes[digest]) {
            revert SignatureSubmitted(digest);
        }

        if (!_isCurrentTimeAcceptable(req.startTime, req.acceptableDeviation)) {
            revert UnacceptableTimeDeviation(req.startTime, req.acceptableDeviation, block.timestamp);
        }

        _placeOrder(req, sig);
    }

    /**
     * @notice Subsequent execute orders after first lot
     * @param orderId order id
     */
    function executeOrder(uint256 orderId) external nonReentrant {
        OrderRequest memory order = orders[orderId];
        OrderRecord memory record = records[orderId];

        if (record.status == OrderStatus.CANCELLED) {
            revert OrderCancelled(orderId);
        }

        if (record.status == OrderStatus.COMPLETED) {
            revert OrderCompleted(orderId);
        }

        uint256 targetTimestamp = record.lastExecutionTimestamp + order.interval;
        if (!_isCurrentTimeAcceptable(targetTimestamp, order.acceptableDeviation)) {
            revert UnacceptableTimeDeviation(targetTimestamp, order.acceptableDeviation, block.timestamp);
        }

        _castSpells(orderId, order);
    }

    /**
     * @notice Cancel off chain order
     * @param req Order request
     * @param sig Off-chain signature
     */
    function cancelOrder(OrderRequest memory req, bytes memory sig) external {
        bytes32 digest = keccak256(sig);

        address signer = _getSigner(req, sig);
        if (msg.sender != signer) {
            revert NotAuthorized(signer, msg.sender);
        }

        cancelledHashes[digest] = true;
        emit OrderCancel(sig);
    }

    /**
     * @notice Cancel Order
     * @param orderId Order ID
     */
    function cancelOrder(uint256 orderId) external {
        OrderRequest memory order = orders[orderId];

        if (msg.sender != order.user) {
            revert NotAuthorized(order.user, msg.sender);
        }

        records[orderId].status = OrderStatus.CANCELLED;
        emit OrderCancel(order.user, order.marketId, orderId);
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

    /**
     * @notice transfer all balance from caller to sender
     */
    function sweep() external requiresAuth {
        (bool success,) = msg.sender.call{value: address(this).balance}("");
        require(success);
    }

    /// -----------------------------------------------------------------------
    /// Internals
    /// -----------------------------------------------------------------------

    /**
     * @notice checks whether block timestamp is within deviation of target timestamp
     * @param targetTimestamp target timestamp
     * @param acceptableDeviation acceptable deviation from target timestamp
     */
    function _isCurrentTimeAcceptable(uint256 targetTimestamp, uint128 acceptableDeviation)
        internal
        view
        returns (bool)
    {
        return targetTimestamp - acceptableDeviation <= block.timestamp
            && block.timestamp <= targetTimestamp + acceptableDeviation;
    }

    /**
     * @notice Validate offchain order and place it's first lot
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

        uint256 orderId = nextOrderId++;
        orders[orderId] = req;
        submittedHashes[keccak256(sig)] = true;

        _castSpells(orderId, req);
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
     * @notice Generate spells to cast
     * @param orderId order id in mapping
     * @param req Order request
     */
    function _castSpells(uint256 orderId, OrderRequest memory req) internal {
        // effects
        records[orderId].iterationsCompleted += 1;
        records[orderId].lastExecutionTimestamp = block.timestamp;
        if (req.totalIterations == records[orderId].iterationsCompleted) {
            records[orderId].status = OrderStatus.COMPLETED;
        }

        // interactions
        bytes32 priceId = priceIds[req.marketId];
        uint256 currentPrice = uint256(pythNode.getLatestPrice(priceId, 0));
        uint256 acceptablePrice =
            req.lotSize > 0 ? currentPrice.mulWadDown(WAD + req.slippage) : currentPrice.mulWadDown(WAD - req.slippage);

        string[] memory targetNames = new string[](1);
        bytes[] memory datas = new bytes[](1);

        targetNames[0] = "Synthetix-Perp-v3-v1.2";

        datas[0] = abi.encodeWithSignature(
            "commitTrade(uint128,uint128,int128,uint256)", req.accountId, req.marketId, req.lotSize, acceptablePrice
        );

        IAccount(req.user).cast(targetNames, datas, address(this));

        emit LotOrderExec(req.user, req.marketId, orderId, records[orderId].iterationsCompleted);
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
        bytes32 reqHash = keccak256(
            abi.encode(
                ORDER_REQUEST_TYPEHASH,
                _req.user,
                _req.accountId,
                _req.marketId,
                _req.lotSize,
                _req.startTime,
                _req.interval,
                _req.totalIterations,
                _req.acceptableDeviation,
                _req.slippage
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, reqHash));
        (uint8 v, bytes32 r, bytes32 s) = _splitSignature(_sig);
        return ecrecover(digest, v, r, s);
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
     * @notice Insufficient fee
     * @param required Required fee
     * @param fee Paid fee
     */
    error InsufficientFee(uint256 required, uint256 fee);

    /**
     * @notice Order is invalid due to startTime or totalIterations
     * @param order Order request
     */
    error InvalidOrder(OrderRequest order);

    /**
     * @notice Executing cancelled order
     * @param orderId ID of the order
     */
    error OrderCancelled(uint256 orderId);

    /**
     * @notice Order already completed
     * @param orderId ID of the order
     */
    error OrderCompleted(uint256 orderId);

    /**
     * @notice deviation from target timestamp is too high
     * @param targetTimestamp target timestamp
     * @param acceptableDeviation acceptable deviaton from target timestamp
     * @param blockTimestamp current timestamp
     */
    error UnacceptableTimeDeviation(uint256 targetTimestamp, uint128 acceptableDeviation, uint256 blockTimestamp);

    /**
     * @notice Executing cancelled order
     * @param digest keccak256 of signature
     */
    error SignatureCancelled(bytes32 digest);

    /**
     * @notice Resubmitting signature
     * @param digest keccak256 of signature
     */
    error SignatureSubmitted(bytes32 digest);

    /**
     * @notice Length mismatch error
     */
    error LengthMismatch();

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    /**
     * @notice Emitted when the order is executed
     * @param user Address of the user (SCW)
     * @param marketId Market ID
     * @param orderId Order ID
     * @param iterationsCompleted how many lots completed
     */
    event LotOrderExec(address indexed user, uint128 indexed marketId, uint256 orderId, uint128 iterationsCompleted);

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

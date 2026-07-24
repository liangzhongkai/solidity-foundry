// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {ERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/ERC20.sol";

import {UniswapV4PoolManagerExample} from "../../src/22-uniswap-v4/UniswapV4PoolManagerExample.sol";
import {UniswapV4PositionManagerExample} from "../../src/22-uniswap-v4/UniswapV4PositionManagerExample.sol";
import {UniswapV4StateViewExample} from "../../src/22-uniswap-v4/UniswapV4StateViewExample.sol";
import {UniswapV4UniversalRouterExample} from "../../src/22-uniswap-v4/UniswapV4UniversalRouterExample.sol";
import {
    BalanceDelta,
    Currency,
    IHooks,
    IPositionManager,
    IStateView,
    IUnlockCallback,
    IUniversalRouter,
    IPermit2,
    ModifyLiquidityParams,
    PoolId,
    PoolIdLibrary,
    PoolKey,
    PositionInfo,
    SwapParams
} from "../../src/22-uniswap-v4/interfaces/IUniswapV4.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockPermit2 is IPermit2 {
    address public lastToken;
    address public lastSpender;
    uint160 public lastAmount;
    uint48 public lastExpiration;

    function approve(address token, address spender, uint160 amount, uint48 expiration) external {
        lastToken = token;
        lastSpender = spender;
        lastAmount = amount;
        lastExpiration = expiration;
    }
}

contract MockUniversalRouter is IUniversalRouter {
    address public outputToken;
    uint256 public outputAmount;

    function setOutput(address outputToken_, uint256 outputAmount_) external {
        outputToken = outputToken_;
        outputAmount = outputAmount_;
    }

    function execute(bytes calldata, bytes[] calldata, uint256) external payable {
        if (outputToken != address(0) && outputAmount > 0) {
            MockERC20(outputToken).transfer(msg.sender, outputAmount);
        }
    }
}

contract MockPoolManager {
    using PoolIdLibrary for PoolKey;

    BalanceDelta public configuredSwapDelta;
    BalanceDelta public configuredModifyDelta;
    BalanceDelta public configuredFeesAccrued;
    BalanceDelta public configuredDonateDelta;
    Currency public lastSyncedCurrency;
    uint256 public syncCount;

    function setSwapDelta(BalanceDelta delta) external {
        configuredSwapDelta = delta;
    }

    function setModifyDelta(BalanceDelta delta, BalanceDelta feesAccrued) external {
        configuredModifyDelta = delta;
        configuredFeesAccrued = feesAccrued;
    }

    function setDonateDelta(BalanceDelta delta) external {
        configuredDonateDelta = delta;
    }

    function unlock(bytes calldata data) external returns (bytes memory) {
        return IUnlockCallback(msg.sender).unlockCallback(data);
    }

    function initialize(PoolKey memory, uint160) external pure returns (int24 tick) {
        return 0;
    }

    function modifyLiquidity(PoolKey memory, ModifyLiquidityParams memory, bytes calldata)
        external
        view
        returns (BalanceDelta callerDelta, BalanceDelta feesAccrued)
    {
        return (configuredModifyDelta, configuredFeesAccrued);
    }

    function swap(
        PoolKey memory,
        /* key */
        SwapParams memory,
        bytes calldata
    )
        external
        view
        returns (BalanceDelta swapDelta)
    {
        return configuredSwapDelta;
    }

    function donate(PoolKey memory, uint256, uint256, bytes calldata) external view returns (BalanceDelta delta) {
        return configuredDonateDelta;
    }

    function sync(Currency currency) external {
        lastSyncedCurrency = currency;
        syncCount++;
    }

    function take(Currency currency, address to, uint256 amount) external {
        MockERC20(Currency.unwrap(currency)).transfer(to, amount);
    }

    function settle() external payable returns (uint256 paid) {
        return 0;
    }

    function settleFor(address) external payable returns (uint256 paid) {
        return 0;
    }

    function clear(Currency, uint256) external {}

    function mint(address, uint256, uint256) external {}

    function burn(address, uint256, uint256) external {}

    function updateDynamicLPFee(PoolKey memory, uint24) external {}
}

contract MockStateView is IStateView {
    uint160 public sqrtPriceX96;
    int24 public tick;
    uint24 public protocolFee;
    uint24 public lpFee;
    uint128 public liquidity;
    uint256 public feeGrowthGlobal0;
    uint256 public feeGrowthGlobal1;
    uint128 public positionLiquidity;
    uint256 public feeGrowthInside0;
    uint256 public feeGrowthInside1;

    function setPoolState(uint160 sqrtPriceX96_, int24 tick_, uint24 protocolFee_, uint24 lpFee_, uint128 liquidity_)
        external
    {
        sqrtPriceX96 = sqrtPriceX96_;
        tick = tick_;
        protocolFee = protocolFee_;
        lpFee = lpFee_;
        liquidity = liquidity_;
    }

    function setFeeGrowthGlobals(uint256 feeGrowthGlobal0_, uint256 feeGrowthGlobal1_) external {
        feeGrowthGlobal0 = feeGrowthGlobal0_;
        feeGrowthGlobal1 = feeGrowthGlobal1_;
    }

    function setPositionInfo(uint128 liquidity_, uint256 feeGrowthInside0_, uint256 feeGrowthInside1_) external {
        positionLiquidity = liquidity_;
        feeGrowthInside0 = feeGrowthInside0_;
        feeGrowthInside1 = feeGrowthInside1_;
    }

    function getSlot0(PoolId) external view returns (uint160, int24, uint24, uint24) {
        return (sqrtPriceX96, tick, protocolFee, lpFee);
    }

    function getFeeGrowthGlobals(PoolId) external view returns (uint256, uint256) {
        return (feeGrowthGlobal0, feeGrowthGlobal1);
    }

    function getLiquidity(PoolId) external view returns (uint128) {
        return liquidity;
    }

    function getPositionInfo(PoolId, address, int24, int24, bytes32) external view returns (uint128, uint256, uint256) {
        return (positionLiquidity, feeGrowthInside0, feeGrowthInside1);
    }
}

contract MockPositionManager is IPositionManager {
    using PoolIdLibrary for PoolKey;

    uint256 public override nextTokenId = 1;

    mapping(uint256 => uint128) internal liquidities;
    mapping(uint256 => PoolKey) internal keys;
    mapping(uint256 => PositionInfo) internal infos;
    mapping(uint256 => address) internal owners;
    mapping(uint256 => address) internal approvals;
    mapping(address => mapping(address => bool)) internal operatorApprovals;

    function modifyLiquidities(bytes calldata unlockData, uint256) external payable {
        (bytes memory actions, bytes[] memory params) = abi.decode(unlockData, (bytes, bytes[]));
        uint8 action = uint8(actions[0]);

        if (action == 0x02) {
            (
                PoolKey memory key,
                int24 tickLower,
                int24 tickUpper,
                uint256 liquidity,
                uint128 amount0Max,
                uint128 amount1Max,
                address recipient,
                bytes memory hookData
            ) = abi.decode(params[0], (PoolKey, int24, int24, uint256, uint128, uint128, address, bytes));
            amount0Max;
            amount1Max;
            recipient;
            hookData;
            uint256 tokenId = nextTokenId++;
            liquidities[tokenId] = uint128(liquidity);
            keys[tokenId] = key;
            infos[tokenId] = _packPositionInfo(key, tickLower, tickUpper);
            owners[tokenId] = recipient;
            return;
        }

        if (action == 0x00) {
            (uint256 tokenId, uint256 liquidity,,,) = abi.decode(params[0], (uint256, uint256, uint128, uint128, bytes));
            liquidities[tokenId] += uint128(liquidity);
            return;
        }

        if (action == 0x01) {
            (uint256 tokenId, uint256 liquidity,,,) = abi.decode(params[0], (uint256, uint256, uint128, uint128, bytes));
            if (liquidity > liquidities[tokenId]) {
                liquidities[tokenId] = 0;
            } else {
                liquidities[tokenId] -= uint128(liquidity);
            }
            return;
        }

        if (action == 0x03) {
            (uint256 tokenId,,,) = abi.decode(params[0], (uint256, uint128, uint128, bytes));
            delete liquidities[tokenId];
            delete keys[tokenId];
            delete owners[tokenId];
            delete approvals[tokenId];
            infos[tokenId] = PositionInfo.wrap(0);
        }
    }

    function modifyLiquiditiesWithoutUnlock(bytes calldata, bytes[] calldata) external payable {}

    function getPositionLiquidity(uint256 tokenId) external view returns (uint128 liquidity) {
        return liquidities[tokenId];
    }

    function getPoolAndPositionInfo(uint256 tokenId) external view returns (PoolKey memory, PositionInfo) {
        return (keys[tokenId], infos[tokenId]);
    }

    function positionInfo(uint256 tokenId) external view returns (PositionInfo) {
        return infos[tokenId];
    }

    function ownerOf(uint256 tokenId) external view returns (address owner) {
        owner = owners[tokenId];
        require(owner != address(0), "owner query for nonexistent token");
    }

    function getApproved(uint256 tokenId) external view returns (address operator) {
        return approvals[tokenId];
    }

    function isApprovedForAll(address owner, address operator) external view returns (bool) {
        return operatorApprovals[owner][operator];
    }

    function setApproved(uint256 tokenId, address operator) external {
        approvals[tokenId] = operator;
    }

    function setApprovedForAll(address owner, address operator, bool approved) external {
        operatorApprovals[owner][operator] = approved;
    }

    function _packPositionInfo(PoolKey memory key, int24 tickLower, int24 tickUpper)
        internal
        pure
        returns (PositionInfo)
    {
        bytes25 truncatedPoolId = bytes25(PoolId.unwrap(key.toId()));
        uint256 packed = uint256(bytes32(truncatedPoolId));
        packed |= uint256(uint24(uint24(uint24(int24(tickLower))))) << 8;
        packed |= uint256(uint24(uint24(uint24(int24(tickUpper))))) << 32;
        return PositionInfo.wrap(packed);
    }
}

contract UniswapV4WrapperUnitTest is Test {
    using PoolIdLibrary for PoolKey;

    MockERC20 internal dai;
    MockERC20 internal weth;
    MockPermit2 internal permit2;
    MockUniversalRouter internal mockRouter;
    MockPoolManager internal mockPoolManager;
    MockStateView internal mockStateView;
    MockPositionManager internal mockPositionManager;

    UniswapV4PoolManagerExample internal poolManagerExample;
    UniswapV4UniversalRouterExample internal routerExample;
    UniswapV4PositionManagerExample internal positionExample;
    UniswapV4StateViewExample internal stateExample;

    address internal trader = makeAddr("trader");
    address internal recipient = makeAddr("recipient");

    function setUp() public {
        dai = new MockERC20("Mock DAI", "mDAI");
        weth = new MockERC20("Mock WETH", "mWETH");
        permit2 = new MockPermit2();
        mockRouter = new MockUniversalRouter();
        mockPoolManager = new MockPoolManager();
        mockStateView = new MockStateView();
        mockPositionManager = new MockPositionManager();

        poolManagerExample = new UniswapV4PoolManagerExample(address(mockPoolManager));
        routerExample = new UniswapV4UniversalRouterExample(address(mockRouter), address(permit2));
        positionExample = new UniswapV4PositionManagerExample(address(mockPositionManager), address(permit2));
        stateExample = new UniswapV4StateViewExample(address(mockStateView), address(mockPositionManager));
    }

    function testPoolManagerSwapSettlesInputAndTakesOutput() public {
        PoolKey memory key = _poolKey();
        mockPoolManager.setSwapDelta(_delta(5 ether, -2 ether));
        dai.mint(address(mockPoolManager), 5 ether);
        weth.mint(trader, 2 ether);

        vm.startPrank(trader);
        weth.approve(address(poolManagerExample), type(uint256).max);
        uint256 amountOut = poolManagerExample.swapExactInput(key, false, 2 ether, 4 ether, 0, bytes(""), recipient);
        vm.stopPrank();

        assertEq(amountOut, 5 ether);
        assertEq(dai.balanceOf(recipient), 5 ether);
        assertEq(weth.balanceOf(address(mockPoolManager)), 2 ether);
        assertEq(mockPoolManager.syncCount(), 1);
        assertEq(Currency.unwrap(mockPoolManager.lastSyncedCurrency()), address(weth));
    }

    function testPoolManagerModifyLiquiditySettlesNegativeDeltas() public {
        PoolKey memory key = _poolKey();
        mockPoolManager.setModifyDelta(_delta(-3 ether, -1 ether), _delta(int128(0.5 ether), int128(0.25 ether)));
        dai.mint(trader, 3 ether);
        weth.mint(trader, 1 ether);

        vm.startPrank(trader);
        dai.approve(address(poolManagerExample), type(uint256).max);
        weth.approve(address(poolManagerExample), type(uint256).max);
        (BalanceDelta callerDelta, BalanceDelta feesAccrued) = poolManagerExample.modifyLiquidity(
            key,
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: int256(1e12), salt: bytes32(0)}),
            bytes(""),
            recipient
        );
        vm.stopPrank();

        assertEq(callerDelta.amount0(), -3 ether);
        assertEq(callerDelta.amount1(), -1 ether);
        assertEq(feesAccrued.amount0(), 0.5 ether);
        assertEq(feesAccrued.amount1(), 0.25 ether);
        assertEq(dai.balanceOf(address(mockPoolManager)), 3 ether);
        assertEq(weth.balanceOf(address(mockPoolManager)), 1 ether);
        assertEq(mockPoolManager.syncCount(), 2);
        assertEq(Currency.unwrap(mockPoolManager.lastSyncedCurrency()), address(weth));
    }

    function testRouterSwapUsesPermit2ApprovalAndTransfersOutput() public {
        PoolKey memory key = _poolKey();
        weth.mint(trader, 2 ether);
        dai.mint(address(mockRouter), 7 ether);
        mockRouter.setOutput(address(dai), 7 ether);

        vm.startPrank(trader);
        weth.approve(address(routerExample), type(uint256).max);
        uint256 amountOut =
            routerExample.swapExactInputSingle(key, false, 2 ether, 0, block.timestamp + 1 hours, recipient, bytes(""));
        vm.stopPrank();

        assertEq(amountOut, 7 ether);
        assertEq(dai.balanceOf(recipient), 7 ether);
        assertEq(permit2.lastToken(), address(weth));
        assertEq(permit2.lastSpender(), address(mockRouter));
        assertEq(permit2.lastAmount(), 2 ether);
    }

    function testStateViewReadsConfiguredPoolStateAndPosition() public {
        PoolKey memory key = _poolKey();
        mockStateView.setPoolState(123, 7, 11, 4242, 999);
        mockStateView.setFeeGrowthGlobals(21, 34);

        bytes memory unlockData = positionExample.encodeMintPositionUnlockData(
            key, -120, 120, 1e12, 10 ether, 10 ether, address(this), bytes("")
        );
        mockPositionManager.modifyLiquidities(unlockData, block.timestamp);

        (PoolId id, uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee, uint128 liquidity) =
            stateExample.readPoolState(key);
        assertEq(PoolId.unwrap(id), PoolId.unwrap(key.toId()));
        assertEq(sqrtPriceX96, 123);
        assertEq(tick, 7);
        assertEq(protocolFee, 11);
        assertEq(lpFee, 4242);
        assertEq(liquidity, 999);

        (PoolKey memory storedKey,, int24 tickLower, int24 tickUpper,, uint128 nftLiquidity) =
            stateExample.readPositionNft(1);
        assertEq(PoolId.unwrap(storedKey.toId()), PoolId.unwrap(key.toId()));
        assertEq(tickLower, -120);
        assertEq(tickUpper, 120);
        assertEq(nftLiquidity, 1e12);
    }

    function testPositionManagerMintIncreaseDecreaseAndBurn() public {
        PoolKey memory key = _poolKey();
        dai.mint(trader, 100 ether);
        weth.mint(trader, 100 ether);

        vm.startPrank(trader);
        dai.approve(address(positionExample), type(uint256).max);
        weth.approve(address(positionExample), type(uint256).max);
        uint256 tokenId = positionExample.mintPosition(
            key, -120, 120, 1e12, 10 ether, 10 ether, block.timestamp + 1 hours, address(positionExample), bytes("")
        );
        positionExample.increaseLiquidity(tokenId, 5e11, 5 ether, 5 ether, block.timestamp + 1 hours, bytes(""));
        positionExample.decreaseLiquidity(tokenId, 5e11, 0, 0, block.timestamp + 1 hours, recipient, bytes(""));
        positionExample.burnPosition(tokenId, 0, 0, block.timestamp + 1 hours, recipient, bytes(""));
        vm.stopPrank();

        assertEq(tokenId, 1);
        assertEq(positionExample.getPositionLiquidity(tokenId), 0);
        assertEq(permit2.lastSpender(), address(mockPositionManager));
    }

    function testPositionManagerRejectsUnauthorizedWrapperOwnedPositionActions() public {
        PoolKey memory key = _poolKey();
        address attacker = makeAddr("attacker");
        dai.mint(trader, 100 ether);
        weth.mint(trader, 100 ether);

        vm.startPrank(trader);
        dai.approve(address(positionExample), type(uint256).max);
        weth.approve(address(positionExample), type(uint256).max);
        uint256 tokenId = positionExample.mintPosition(
            key, -120, 120, 1e12, 10 ether, 10 ether, block.timestamp + 1 hours, address(positionExample), bytes("")
        );
        vm.stopPrank();

        assertEq(positionExample.positionController(tokenId), trader);

        vm.prank(attacker);
        vm.expectRevert(UniswapV4PositionManagerExample.NotPositionOwnerOrApproved.selector);
        positionExample.collectFees(tokenId, block.timestamp + 1 hours, attacker, bytes(""));

        vm.prank(attacker);
        vm.expectRevert(UniswapV4PositionManagerExample.NotPositionOwnerOrApproved.selector);
        positionExample.decreaseLiquidity(tokenId, 1, 0, 0, block.timestamp + 1 hours, attacker, bytes(""));

        vm.prank(attacker);
        vm.expectRevert(UniswapV4PositionManagerExample.NotPositionOwnerOrApproved.selector);
        positionExample.burnPosition(tokenId, 0, 0, block.timestamp + 1 hours, attacker, bytes(""));
    }

    function _poolKey() internal view returns (PoolKey memory key) {
        key = PoolKey({
            currency0: Currency.wrap(address(dai)),
            currency1: Currency.wrap(address(weth)),
            fee: 4242,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });
    }

    function _delta(int128 amount0, int128 amount1) internal pure returns (BalanceDelta balanceDelta) {
        assembly ("memory-safe") {
            balanceDelta := or(shl(128, amount0), and(sub(shl(128, 1), 1), amount1))
        }
    }
}

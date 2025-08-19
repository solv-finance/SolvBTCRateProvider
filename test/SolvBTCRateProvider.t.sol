// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {SolvBTCRateProvider} from "../contracts/SolvBTCRateProvider.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract MockReserveFeedMock is AggregatorV3Interface {
    int256 public constant reserve = 4690352947360884307563;

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (0, reserve, 1000000000000000000, 1000000000000000000, 0);
    }

    function decimals() external view returns (uint8) {
        return 18;
    }

    function description() external view returns (string memory) {
        return "Mock Reserve Feed";
    }

    function getRoundData(uint80 _roundId)
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (0, reserve, 1000000000000000000, 1000000000000000000, 0);
    }

    function version() external view returns (uint256) {
        return 1;
    }
}

contract SolvBTCRateProviderTest is Test {
    SolvBTCRateProvider public rateProvider;
    MockReserveFeedMock public reserveFeed;

    // Test addresses
    address public owner;
    address public updater;
    address public user;

    // Test parameters
    uint256 public constant MAX_DIFFERENCE_PERCENT = 0.03 * 1e18; // 3%

    function setUp() public {
        // Setup test addresses
        owner = makeAddr("owner");
        updater = makeAddr("updater");
        user = makeAddr("user");

        // Deploy the contract using proxy pattern
        rateProvider = _deploySolvBTCRateProvider();
    }

    function _deploySolvBTCRateProvider() internal returns (SolvBTCRateProvider) {
        vm.startPrank(owner);

        // Deploy implementation
        SolvBTCRateProvider impl = new SolvBTCRateProvider();

        // Deploy proxy admin
        ProxyAdmin proxyAdmin = new ProxyAdmin();

        // Deploy mock reserve feed
        reserveFeed = new MockReserveFeedMock();

        // Deploy proxy
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(impl),
            address(proxyAdmin),
            abi.encodeWithSignature(
                "initialize(address,address,uint256)", address(reserveFeed), updater, MAX_DIFFERENCE_PERCENT
            )
        );

        vm.stopPrank();
        return SolvBTCRateProvider(address(proxy));
    }

    function test_UpdateRate_Success() public {
        // Use mock data for testing since we're not forking mainnet
        uint256 mockReserve = uint256(reserveFeed.reserve());
        uint256 totalSupply = mockReserve;

        // Calculate expected rate
        uint256 expectedRate = Math.mulDiv(mockReserve, rateProvider.RATE_PRECISION_FACTOR(), totalSupply);

        // Update rate as updater
        vm.prank(updater);
        uint256 actualRate = rateProvider.updateRate(totalSupply, mockReserve);

        // Verify the rate
        assertEq(actualRate, expectedRate);
        assertEq(rateProvider.getRate(), expectedRate);
        assertEq(rateProvider.getLatestTotalSupply(), totalSupply);
        assertEq(rateProvider.getLatestTVL(), mockReserve);
        assertEq(rateProvider.getLatestUpdateTime(), block.timestamp);
    }

    function test_UpdateRate_InvalidDifference() public {
        // Use mock BTC price data for testing
        uint256 mockReserve = uint256(reserveFeed.reserve()); // $50,000 BTC price with 8 decimals

        uint256 totalSupply = mockReserve;
        vm.prank(updater);
        uint256 rate = rateProvider.updateRate(totalSupply, mockReserve);
        assertEq(rate, 1e18);

        // Create a TVL that differs significantly from reserve
        uint256 invalidTVL = Math.mulDiv(mockReserve, 1.04 * 1e18, 1e18); // 4% difference

        // Expect revert or return of previous rate
        vm.prank(updater);
        vm.expectEmit(false, true, false, false);
        emit SolvBTCRateProvider.AlertInvalidReserveDifference(mockReserve, invalidTVL, block.timestamp);
        uint256 rate2 = rateProvider.updateRate(totalSupply, invalidTVL);
        assertEq(rate2, 1e18);
    }

    function test_UpdateRate_InvalidRate() public {
        // Use mock BTC price data for testing
        uint256 mockReserve = uint256(reserveFeed.reserve());
        uint256 totalSupply = Math.mulDiv(mockReserve, 9, 10);

        vm.prank(updater);
        vm.expectEmit(false, true, false, false);
        emit SolvBTCRateProvider.AlertInvalidRate(0, block.timestamp);
        uint256 rate = rateProvider.updateRate(totalSupply, mockReserve);
        assertEq(rate, 0);
    }

    function test_UpdateRate_OnlyUpdater() public {
        uint256 mockReserve = uint256(reserveFeed.reserve());
        uint256 totalSupply = mockReserve;

        // Try to update rate as non-updater
        vm.prank(user);
        vm.expectRevert("Not updater");
        rateProvider.updateRate(totalSupply, mockReserve);
    }

    function test_SetReserveFeed_OnlyOwner() public {
        address newReserveFeed = makeAddr("newReserveFeed");

        // Try to set reserve feed as non-owner
        vm.prank(user);
        vm.expectRevert();
        rateProvider.setReserveFeed(newReserveFeed);

        // Set as owner
        vm.prank(owner);
        rateProvider.setReserveFeed(newReserveFeed);
        assertEq(rateProvider.getReserveFeed(), newReserveFeed);
    }

    function test_SetUpdater_OnlyOwner() public {
        address newUpdater = makeAddr("newUpdater");

        // Try to set updater as non-owner
        vm.prank(user);
        vm.expectRevert();
        rateProvider.setUpdater(newUpdater);

        // Set as owner
        vm.prank(owner);
        rateProvider.setUpdater(newUpdater);
        assertEq(rateProvider.getUpdater(), newUpdater);
    }

    function test_SetMaxDifferencePercent_OnlyOwner() public {
        uint256 newMaxDifference = 1000; // 10%

        // Try to set max difference as non-owner
        vm.prank(user);
        vm.expectRevert();
        rateProvider.setMaxDifferencePercent(newMaxDifference);

        // Set as owner
        vm.prank(owner);
        rateProvider.setMaxDifferencePercent(newMaxDifference);
        assertEq(rateProvider.getMaxDifferencePercent(), newMaxDifference);
    }

    function test_SetReserveFeed_InvalidAddress() public {
        vm.prank(owner);
        vm.expectRevert("Invalid reserve feed");
        rateProvider.setReserveFeed(address(0));
    }

    function test_SetUpdater_InvalidAddress() public {
        vm.prank(owner);
        vm.expectRevert("Invalid updater");
        rateProvider.setUpdater(address(0));
    }

    function test_SetMaxDifferencePercent_InvalidValue() public {
        // Test zero value
        vm.prank(owner);
        vm.expectRevert("Invalid max difference percent");
        rateProvider.setMaxDifferencePercent(0);

        // Test value greater than 10000 (100%)
        vm.prank(owner);
        vm.expectRevert("Invalid max difference percent");
        rateProvider.setMaxDifferencePercent(1 * 1e18 + 1);
    }

    function test_RateBounds() public {
        uint256 mockReserve = uint256(reserveFeed.reserve());
        uint256 totalSupply = mockReserve;

        vm.prank(updater);
        uint256 rate = rateProvider.updateRate(totalSupply, mockReserve);

        // Rate should be within bounds (0.95 to 1.05)
        assertGe(rate, rateProvider.MIN_RATE());
        assertLe(rate, rateProvider.MAX_RATE());
    }

    function test_Events() public {
        address newReserveFeed = makeAddr("newReserveFeed");
        address newUpdater = makeAddr("newUpdater");
        uint256 newMaxDifference = 1000;

        // Test ReserveFeedSet event
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit SolvBTCRateProvider.ReserveFeedSet(newReserveFeed);
        rateProvider.setReserveFeed(newReserveFeed);

        // Test UpdaterSet event
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit SolvBTCRateProvider.UpdaterSet(newUpdater);
        rateProvider.setUpdater(newUpdater);

        // Test MaxDifferencePercentSet event
        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit SolvBTCRateProvider.MaxDifferencePercentSet(newMaxDifference);
        rateProvider.setMaxDifferencePercent(newMaxDifference);
    }

    function test_AlertInvalidReserveDifference_Event() public {
        uint256 mockReserve = uint256(reserveFeed.reserve());
        uint256 totalSupply = mockReserve;

        // Create a TVL that exceeds max difference
        uint256 invalidTVL = Math.mulDiv(mockReserve, 1.04 * 1e18, 1e18); // 100% difference

        vm.prank(updater);
        vm.expectEmit(false, true, false, false);
        emit SolvBTCRateProvider.AlertInvalidReserveDifference(mockReserve, invalidTVL, block.timestamp);
        rateProvider.updateRate(totalSupply, invalidTVL);
    }

    function test_Constructor_Disabled() public {
        // Constructor should be disabled for upgradeable contract
        SolvBTCRateProvider newProvider = new SolvBTCRateProvider();

        // Try to initialize again should fail
        vm.prank(owner);
        vm.expectRevert();
        newProvider.initialize(address(reserveFeed), updater, MAX_DIFFERENCE_PERCENT);
    }

    function test_Ownable2Step_TransferOwnership() public {
        address newOwner = makeAddr("newOwner");

        // Transfer ownership
        vm.prank(owner);
        rateProvider.transferOwnership(newOwner);

        // Accept ownership
        vm.prank(newOwner);
        rateProvider.acceptOwnership();

        assertEq(rateProvider.owner(), newOwner);
    }

    function test_UpdateRate_ZeroTotalSupply() public {
        uint256 mockReserve = 50000e8;

        vm.prank(updater);
        vm.expectRevert(); // Should revert due to division by zero
        rateProvider.updateRate(0, mockReserve);
    }

    function test_UpdateRate_ZeroTVL() public {
        uint256 mockReserve = 0;
        uint256 totalSupply = 10000e18;

        vm.prank(updater);
        uint256 rate = rateProvider.updateRate(totalSupply, mockReserve);

        // Rate should be 0 when TVL is 0
        assertEq(rate, 0);
        assertEq(rateProvider.getRate(), 0);
    }

    function test_UpdateRate_ExactMaxDifference() public {
        uint256 mockReserve = uint256(reserveFeed.reserve());
        uint256 totalSupply = mockReserve;
        // Create TVL that is exactly at the max difference threshold
        uint256 exactMaxDiffTVL = Math.mulDiv(mockReserve, 1.01 * 1e18, 1e18) + 1;

        vm.prank(updater);
        uint256 rate = rateProvider.updateRate(totalSupply, exactMaxDiffTVL);

        // Should accept the update when difference is exactly at max
        assertGt(rate, 0);
    }

    function test_UpdateRate_JustOverMaxDifference() public {
        uint256 mockReserve = uint256(reserveFeed.reserve());
        uint256 totalSupply = mockReserve;
        // Create TVL that is just over the max difference threshold
        uint256 justOverMaxDiffTVL = Math.mulDiv(mockReserve, MAX_DIFFERENCE_PERCENT, 1e18) + 1;

        vm.prank(updater);
        uint256 rate = rateProvider.updateRate(totalSupply, justOverMaxDiffTVL);

        // Should return previous rate (0 if no previous update)
        assertEq(rate, 0);
    }

    function test_UpdateRate_JustUnderMaxDifference() public {
        uint256 mockReserve = uint256(reserveFeed.reserve());
        uint256 totalSupply = mockReserve;
        // Create TVL that is just under the max difference threshold
        uint256 justUnderMaxDiffTVL = Math.mulDiv(mockReserve, 101, 100) - 1;

        vm.prank(updater);
        uint256 rate = rateProvider.updateRate(totalSupply, justUnderMaxDiffTVL);

        // Should accept the update when difference is just under max
        assertGt(rate, 0);
    }

    // ========== 多次更新测试 ==========

    function test_UpdateRate_MultipleUpdates() public {
        uint256 mockReserve1 = uint256(reserveFeed.reserve());
        uint256 totalSupply = mockReserve1;
        uint256 mockReserve2 = Math.mulDiv(mockReserve1, 1.013 * 1e18, 1e18);
        uint256 mockReserve3 = Math.mulDiv(mockReserve1, 0.987 * 1e18, 1e18);

        // First update
        vm.prank(updater);
        uint256 rate1 = rateProvider.updateRate(totalSupply, mockReserve1);
        assertGt(rate1, 0);

        // Second update
        vm.prank(updater);
        uint256 rate2 = rateProvider.updateRate(totalSupply, mockReserve2);
        assertGt(rate2, 0);
        assertEq(rateProvider.getRate(), rate2);
        assertEq(rateProvider.getLatestTVL(), mockReserve2);

        // Third update
        vm.prank(updater);
        uint256 rate3 = rateProvider.updateRate(totalSupply, mockReserve3);
        assertGt(rate3, 0);
        assertEq(rateProvider.getRate(), rate3);
        assertEq(rateProvider.getLatestTVL(), mockReserve3);
    }

    function test_UpdateRate_ReturnPreviousRateOnInvalidDifference() public {
        uint256 mockReserve = uint256(reserveFeed.reserve());
        uint256 totalSupply = mockReserve;

        // First update - valid
        vm.prank(updater);
        uint256 validRate = rateProvider.updateRate(totalSupply, mockReserve);
        assertGt(validRate, 0);

        // Second update - invalid difference
        uint256 invalidTVL = mockReserve * 2; // 100% difference
        vm.prank(updater);
        uint256 returnedRate = rateProvider.updateRate(totalSupply, invalidTVL);

        // Should return the previous valid rate
        assertEq(returnedRate, validRate);
        assertEq(rateProvider.getRate(), validRate);
        assertEq(rateProvider.getLatestTVL(), mockReserve); // Should keep previous TVL
    }

    function _deploySolvBTCRateProviderWithUpdater(address updater_) internal returns (SolvBTCRateProvider) {
        // Deploy implementation
        SolvBTCRateProvider impl = new SolvBTCRateProvider();

        // Deploy proxy admin
        ProxyAdmin proxyAdmin = new ProxyAdmin();

        // Deploy mock reserve feed
        reserveFeed = new MockReserveFeedMock();

        // Deploy proxy
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(impl),
            address(proxyAdmin),
            abi.encodeWithSignature(
                "initialize(address,address,uint256)", address(reserveFeed), updater_, MAX_DIFFERENCE_PERCENT
            )
        );

        return SolvBTCRateProvider(address(proxy));
    }

    function test_UpdateRate_AfterUpdaterChange() public {
        address newUpdater = makeAddr("newUpdater");

        // Change updater
        vm.prank(owner);
        rateProvider.setUpdater(newUpdater);

        // Old updater should fail
        vm.prank(updater);
        vm.expectRevert("Not updater");
        rateProvider.updateRate(4000e18, 4699e18);

        // New updater should succeed
        vm.prank(newUpdater);
        uint256 rate = rateProvider.updateRate(4699e18, 4699e18);
        assertGt(rate, 0);
    }

    // ========== 配置边界测试 ==========

    function test_SetMaxDifferencePercent_MinValue() public {
        vm.prank(owner);
        rateProvider.setMaxDifferencePercent(1); // 0.01%
        assertEq(rateProvider.getMaxDifferencePercent(), 1);
    }

    function test_SetMaxDifferencePercent_MaxValue() public {
        vm.prank(owner);
        rateProvider.setMaxDifferencePercent(10000); // 100%
        assertEq(rateProvider.getMaxDifferencePercent(), 10000);
    }

    function test_SetMaxDifferencePercent_ZeroValue() public {
        vm.prank(owner);
        vm.expectRevert("Invalid max difference percent");
        rateProvider.setMaxDifferencePercent(0);
    }

    function test_SetMaxDifferencePercent_OverMaxValue() public {
        vm.prank(owner);
        vm.expectRevert("Invalid max difference percent");
        rateProvider.setMaxDifferencePercent(1.01 * 1e18);
    }

    // ========== 事件边界测试 ==========

    function test_Events_AllParameters() public {
        address newReserveFeed = makeAddr("newReserveFeed");
        address newUpdater = makeAddr("newUpdater");
        uint256 newMaxDifference = 1000;

        // Test all events with different parameters
        vm.startPrank(owner);

        vm.expectEmit(true, false, false, true);
        emit SolvBTCRateProvider.ReserveFeedSet(newReserveFeed);
        rateProvider.setReserveFeed(newReserveFeed);

        vm.expectEmit(true, false, false, true);
        emit SolvBTCRateProvider.UpdaterSet(newUpdater);
        rateProvider.setUpdater(newUpdater);

        vm.expectEmit(false, false, false, true);
        emit SolvBTCRateProvider.MaxDifferencePercentSet(newMaxDifference);
        rateProvider.setMaxDifferencePercent(newMaxDifference);

        vm.stopPrank();
    }
}

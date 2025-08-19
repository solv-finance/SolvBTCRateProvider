// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract SolvBTCRateProvider is Initializable, Ownable2StepUpgradeable {
    struct RateProviderStorage {
        address reserveFeed;
        address updater;
        uint256 maxDifferencePercent; // decimals is 18
        uint256 latestUpdateTime;
        uint256 latestTotalSupply;
        uint256 latestReserve;
        uint256 latestRate;
    }

    event ReserveFeedSet(address indexed reserveFeed);
    event UpdaterSet(address indexed updater);
    event MaxDifferencePercentSet(uint256 maxDifferencePercent);
    event AlertInvalidReserve(int256 indexed reserve, uint256 indexed timestamp);
    event AlertInvalidReserveDifference(uint256 indexed reserve, uint256 indexed tvl, uint256 indexed timestamp);
    event AlertInvalidRate(uint256 indexed rate, uint256 indexed timestamp);
    event LatestRateUpdated(uint256 indexed rate, uint256 indexed timestamp);

    // keccak256(abi.encode(uint256(keccak256("solv.storage.SolvBTCRateProvider")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant _RATE_PROVIDER_STORAGE_SLOT =
        0xc8c866c3e879217162bd80a59ef0b1bbdd0d0754eefb3fd6155ad5f531dbc400;
    uint256 public constant RATE_PRECISION_FACTOR = 1e18;
    uint256 public constant MIN_RATE = 985 * RATE_PRECISION_FACTOR / 1000; // 0.985
    uint256 public constant MAX_RATE = 1015 * RATE_PRECISION_FACTOR / 1000; // 1.015

    modifier onlyUpdater() {
        RateProviderStorage storage $ = _getStorage();
        require(msg.sender == $.updater, "Not updater");
        _;
    }

    //disable constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address reserveFeed_, address updater_, uint256 maxDifferencePercent_) public initializer {
        _setReserveFeed(reserveFeed_);
        _setUpdater(updater_);
        _setMaxDifferencePercent(maxDifferencePercent_);
        __Ownable2Step_init();
    }

    /**
     * @notice Update the rate of the Solv token
     * @param totalSupply_ The total supply of the SolvBTC, decimals is 18
     * @param totalTVL_ The total TVL of the SolvBTC, decimals is 18, because the reserve feed is in 18 decimals
     */
    function updateRate(uint256 totalSupply_, uint256 totalTVL_) external onlyUpdater returns (uint256) {
        require(totalSupply_ > 0, "Total supply is zero");
        RateProviderStorage storage $ = _getStorage();
        AggregatorV3Interface reserveFeed = AggregatorV3Interface($.reserveFeed);
        (
            /*uint80 roundID*/
            ,
            int256 reserve,
            /*uint startedAt*/
            ,
            /*uint timeStamp*/
            ,
            /*uint80 answeredInRound*/
        ) = reserveFeed.latestRoundData();
        if (reserve < 0) {
            emit AlertInvalidReserve(reserve, block.timestamp);
            return $.latestRate;
        }
        uint256 latestReserve = uint256(reserve);
        uint256 difference = 0;
        if (latestReserve > totalTVL_) {
            difference = Math.mulDiv(latestReserve - totalTVL_, RATE_PRECISION_FACTOR, latestReserve);
        } else {
            difference = Math.mulDiv(totalTVL_ - latestReserve, RATE_PRECISION_FACTOR, totalTVL_);
        }
        if (difference > $.maxDifferencePercent) {
            emit AlertInvalidReserveDifference(latestReserve, totalTVL_, block.timestamp);
            return $.latestRate;
        }
        uint256 latestRate = Math.mulDiv(totalTVL_, RATE_PRECISION_FACTOR, totalSupply_);
        if (latestRate < MIN_RATE || latestRate > MAX_RATE) {
            emit AlertInvalidRate(latestRate, block.timestamp);
            return $.latestRate;
        }

        $.latestReserve = totalTVL_;
        $.latestTotalSupply = totalSupply_;
        $.latestUpdateTime = block.timestamp;
        $.latestRate = latestRate;
        emit LatestRateUpdated(latestRate, block.timestamp);
        return latestRate;
    }

    function setReserveFeed(address reserveFeed) external onlyOwner {
        _setReserveFeed(reserveFeed);
    }

    function setUpdater(address updater) external onlyOwner {
        _setUpdater(updater);
    }

    function setMaxDifferencePercent(uint256 maxDifferencePercent) external onlyOwner {
        _setMaxDifferencePercent(maxDifferencePercent);
    }

    function getReserveFeed() external view returns (address) {
        RateProviderStorage storage $ = _getStorage();
        return $.reserveFeed;
    }

    function getUpdater() external view returns (address) {
        RateProviderStorage storage $ = _getStorage();
        return $.updater;
    }

    function getMaxDifferencePercent() external view returns (uint256) {
        RateProviderStorage storage $ = _getStorage();
        return $.maxDifferencePercent;
    }

    function getLatestTotalSupply() external view returns (uint256) {
        RateProviderStorage storage $ = _getStorage();
        return $.latestTotalSupply;
    }

    function getLastTVL() external view returns (uint256) {
        RateProviderStorage storage $ = _getStorage();
        return $.latestReserve;
    }

    function getLatestUpdateTime() external view returns (uint256) {
        RateProviderStorage storage $ = _getStorage();
        return $.latestUpdateTime;
    }

    function getRate() public view returns (uint256) {
        RateProviderStorage storage $ = _getStorage();
        return $.latestRate;
    }

    function _getStorage() private pure returns (RateProviderStorage storage $) {
        assembly {
            $.slot := _RATE_PROVIDER_STORAGE_SLOT
        }
        return $;
    }

    function _setReserveFeed(address reserveFeed) internal {
        require(reserveFeed != address(0), "Invalid reserve feed");
        RateProviderStorage storage $ = _getStorage();
        $.reserveFeed = reserveFeed;
        emit ReserveFeedSet(reserveFeed);
    }

    function _setUpdater(address updater) internal {
        require(updater != address(0), "Invalid updater");
        RateProviderStorage storage $ = _getStorage();
        $.updater = updater;
        emit UpdaterSet(updater);
    }

    function _setMaxDifferencePercent(uint256 maxDifferencePercent) internal {
        require(
            maxDifferencePercent > 0 && maxDifferencePercent <= RATE_PRECISION_FACTOR, "Invalid max difference percent"
        );
        RateProviderStorage storage $ = _getStorage();
        $.maxDifferencePercent = maxDifferencePercent;
        emit MaxDifferencePercentSet(maxDifferencePercent);
    }
}

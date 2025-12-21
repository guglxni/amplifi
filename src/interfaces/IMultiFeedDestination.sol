// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IMultiFeedDestination
 * @notice Interface for the Reactive Cross-Chain Oracle (reactive-bounty-1)
 * @dev Deployed at 0x889c32f46E273fBd0d5B1806F3f1286010cD73B3 on Sepolia
 * 
 * This oracle mirrors Chainlink price feeds from Base Sepolia to Ethereum Sepolia
 * using Reactive Network's cross-chain infrastructure.
 */
interface IMultiFeedDestination {
    
    /**
     * @notice Get the latest price data for a specific feed
     * @param originFeed The address of the Chainlink aggregator on Base Sepolia
     * @return roundId The round ID
     * @return answer The price (8 decimals)
     * @return startedAt Timestamp when round started
     * @return updatedAt Timestamp of last update
     * @return answeredInRound The round in which answer was computed
     */
    function latestRoundDataForFeed(address originFeed) external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );
    
    /**
     * @notice Get just the latest price for a feed
     * @param originFeed The address of the Chainlink aggregator on Base Sepolia
     * @return The latest price (8 decimals)
     */
    function getLatestPrice(address originFeed) external view returns (int256);
    
    /**
     * @notice Get the number of decimals for a feed
     * @param originFeed The address of the Chainlink aggregator on Base Sepolia
     * @return The number of decimals (usually 8)
     */
    function decimalsForFeed(address originFeed) external view returns (uint8);
    
    /**
     * @notice Check if a feed has been updated
     * @param originFeed The address of the Chainlink aggregator on Base Sepolia
     * @return True if the feed has at least one update
     */
    function hasFeedData(address originFeed) external view returns (bool);
}

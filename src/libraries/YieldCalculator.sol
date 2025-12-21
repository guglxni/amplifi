// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title YieldCalculator
 * @notice Library for yield comparison and rebalancing calculations
 * @dev Used by YieldOptimizerReactive to determine optimal allocations
 */
library YieldCalculator {
    /// @notice Basis points constant (100% = 10000)
    uint256 constant BPS = 10000;
    
    /// @notice Ray precision for Aave APY (1e27)
    uint256 constant RAY = 1e27;
    
    /// @notice Default minimum yield difference to trigger rebalance (0.5% = 50 bps)
    uint256 constant DEFAULT_MIN_YIELD_DIFF_BPS = 50;
    
    /// @notice Default minimum allocation per pool (20% = 2000 bps)
    uint256 constant DEFAULT_MIN_ALLOCATION_BPS = 2000;

    // ═══════════════════════════════════════════════════════════════
    //                      DECISION LOGIC
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Determine if rebalancing is beneficial
     * @param poolA_APY APY of pool A (can be RAY or any consistent unit)
     * @param poolB_APY APY of pool B (same unit as poolA_APY)
     * @param minDiffBps Minimum APY difference in basis points to trigger rebalance
     * @return shouldTrigger True if yield difference exceeds threshold
     * @return higherYieldPool 0 for Pool A, 1 for Pool B
     */
    function shouldRebalance(
        uint256 poolA_APY,
        uint256 poolB_APY,
        uint256 minDiffBps
    ) internal pure returns (bool shouldTrigger, uint8 higherYieldPool) {
        // Handle zero case
        if (poolA_APY == 0 && poolB_APY == 0) {
            return (false, 0);
        }
        
        // Calculate absolute difference
        uint256 diff;
        if (poolA_APY > poolB_APY) {
            diff = poolA_APY - poolB_APY;
            higherYieldPool = 0;
        } else {
            diff = poolB_APY - poolA_APY;
            higherYieldPool = 1;
        }
        
        // Calculate difference as percentage of higher yield
        uint256 higherYield = poolA_APY > poolB_APY ? poolA_APY : poolB_APY;
        uint256 diffBps = (diff * BPS) / higherYield;
        
        shouldTrigger = diffBps >= minDiffBps;
    }

    /**
     * @notice Calculate optimal allocation based on 80/20 strategy
     * @dev Allocates 80% to higher yield pool, 20% to lower yield pool
     * @param poolA_APY APY of pool A
     * @param poolB_APY APY of pool B
     * @param minAllocationBps Minimum allocation per pool in basis points
     * @return poolA_pct Allocation for pool A in basis points
     * @return poolB_pct Allocation for pool B in basis points
     */
    function calculateOptimalAllocation(
        uint256 poolA_APY,
        uint256 poolB_APY,
        uint256 minAllocationBps
    ) internal pure returns (uint256 poolA_pct, uint256 poolB_pct) {
        // Ensure minimum allocation is reasonable
        require(minAllocationBps <= 5000, "Min allocation too high");
        
        uint256 majorAllocation = BPS - minAllocationBps; // e.g., 8000 (80%)
        
        if (poolA_APY >= poolB_APY) {
            // Pool A has higher or equal yield
            poolA_pct = majorAllocation;
            poolB_pct = minAllocationBps;
        } else {
            // Pool B has higher yield
            poolA_pct = minAllocationBps;
            poolB_pct = majorAllocation;
        }
    }

    /**
     * @notice Calculate proportional allocation based on APY ratio
     * @dev Allocates funds proportionally to yield (higher yield = more allocation)
     * @param poolA_APY APY of pool A
     * @param poolB_APY APY of pool B
     * @param minAllocationBps Minimum allocation per pool in basis points
     * @return poolA_pct Allocation for pool A in basis points
     * @return poolB_pct Allocation for pool B in basis points
     */
    function calculateProportionalAllocation(
        uint256 poolA_APY,
        uint256 poolB_APY,
        uint256 minAllocationBps
    ) internal pure returns (uint256 poolA_pct, uint256 poolB_pct) {
        require(minAllocationBps <= 5000, "Min allocation too high");
        
        uint256 totalAPY = poolA_APY + poolB_APY;
        
        // Handle edge case where both are 0
        if (totalAPY == 0) {
            return (5000, 5000); // 50/50 split
        }
        
        // Calculate proportional allocation
        poolA_pct = (poolA_APY * BPS) / totalAPY;
        poolB_pct = BPS - poolA_pct;
        
        // Enforce minimum allocations
        if (poolA_pct < minAllocationBps) {
            poolA_pct = minAllocationBps;
            poolB_pct = BPS - minAllocationBps;
        } else if (poolB_pct < minAllocationBps) {
            poolB_pct = minAllocationBps;
            poolA_pct = BPS - minAllocationBps;
        }
    }

    // ═══════════════════════════════════════════════════════════════
    //                      UTILITY FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Convert Aave RAY rate to APY percentage (basis points)
     * @dev Aave returns liquidity rate in RAY (1e27), representing per-second rate
     *      APY = rate * seconds_per_year / RAY
     * @param rayRate Rate in RAY format (1e27)
     * @return apyBps APY in basis points (e.g., 350 = 3.5%)
     */
    function rayToAPYBps(uint256 rayRate) internal pure returns (uint256 apyBps) {
        // Seconds per year (365.25 days)
        uint256 SECONDS_PER_YEAR = 31557600;
        
        // APY in RAY = rayRate * SECONDS_PER_YEAR (simplified, ignoring compounding)
        // Then convert to basis points: * 10000 / 1e27
        apyBps = (rayRate * SECONDS_PER_YEAR * BPS) / RAY;
    }

    /**
     * @notice Calculate the APY difference in absolute basis points
     * @param poolA_APY APY of pool A (RAY format)
     * @param poolB_APY APY of pool B (RAY format)
     * @return diffBps Absolute difference in basis points
     */
    function calculateAPYDiffBps(
        uint256 poolA_APY,
        uint256 poolB_APY
    ) internal pure returns (uint256 diffBps) {
        uint256 diff = poolA_APY > poolB_APY 
            ? poolA_APY - poolB_APY 
            : poolB_APY - poolA_APY;
        
        // Convert difference to basis points relative to higher yield
        uint256 higherYield = poolA_APY > poolB_APY ? poolA_APY : poolB_APY;
        if (higherYield == 0) return 0;
        
        diffBps = (diff * BPS) / higherYield;
    }

    /**
     * @notice Get the higher-yielding pool
     * @param poolA_APY APY of pool A
     * @param poolB_APY APY of pool B
     * @return poolIndex 0 for Pool A, 1 for Pool B
     */
    function getHigherYieldPool(
        uint256 poolA_APY,
        uint256 poolB_APY
    ) internal pure returns (uint8 poolIndex) {
        return poolA_APY >= poolB_APY ? 0 : 1;
    }

    /**
     * @notice Calculate amount to move during rebalance
     * @param totalValue Total value in vault
     * @param currentPoolA_pct Current allocation in pool A (basis points)
     * @param targetPoolA_pct Target allocation in pool A (basis points)
     * @return moveAmount Amount to move between pools
     * @return moveToPoolA True if moving to Pool A, false if to Pool B
     */
    function calculateRebalanceAmount(
        uint256 totalValue,
        uint256 currentPoolA_pct,
        uint256 targetPoolA_pct
    ) internal pure returns (uint256 moveAmount, bool moveToPoolA) {
        if (targetPoolA_pct > currentPoolA_pct) {
            // Need to move funds TO Pool A (FROM Pool B)
            uint256 diffPct = targetPoolA_pct - currentPoolA_pct;
            moveAmount = (totalValue * diffPct) / BPS;
            moveToPoolA = true;
        } else {
            // Need to move funds TO Pool B (FROM Pool A)
            uint256 diffPct = currentPoolA_pct - targetPoolA_pct;
            moveAmount = (totalValue * diffPct) / BPS;
            moveToPoolA = false;
        }
    }
}

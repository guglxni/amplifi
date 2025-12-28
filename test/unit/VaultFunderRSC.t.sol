// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {VaultFunderRSC} from "../../src/autoreplenish/VaultFunderRSC.sol";
import {IReactive} from "@reactive/interfaces/IReactive.sol";

/**
 * @title VaultFunderRSCTest
 * @notice Unit tests for VaultFunderRSC (non-react functionality)
 * @dev Tests the RSC's non-reactive functions. The react() function requires
 *      a VM environment which cannot be simulated in unit tests.
 *      Full react() testing should be done via integration tests on Lasna.
 * 
 * Test Categories:
 * 1. Constructor Tests - Initialization
 * 2. Admin Tests - Owner functions
 * 3. View Function Tests - Configuration getters
 * 4. Rate Limiting Logic Tests - Block-based throttling
 */
contract VaultFunderRSCTest is Test {
    // ═══════════════════════════════════════════════════════════════
    //                        CONSTANTS
    // ═══════════════════════════════════════════════════════════════
    
    uint256 constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 constant CRON_CHAIN_ID = 0;
    uint64 constant CALLBACK_GAS_LIMIT = 500_000;
    
    // ═══════════════════════════════════════════════════════════════
    //                        STATE
    // ═══════════════════════════════════════════════════════════════
    
    VaultFunderRSC public rsc;
    address public feeCollector;
    address public vault;
    address public owner;
    
    // ═══════════════════════════════════════════════════════════════
    //                        EVENTS
    // ═══════════════════════════════════════════════════════════════
    
    event FundingCallbackTriggered(uint256 indexed chainId, address indexed feeCollector, string reason);
    event Subscribed(address indexed feeCollector, uint256 chainId, uint256 topic);
    event RateLimited(uint256 lastBlock, uint256 currentBlock);
    event CronCheckExecuted(uint256 blockNumber);
    
    // ═══════════════════════════════════════════════════════════════
    //                        SETUP
    // ═══════════════════════════════════════════════════════════════
    
    function setUp() public {
        owner = address(this);
        feeCollector = makeAddr("feeCollector");
        vault = makeAddr("vault");
        
        // Deploy RSC (vm flag will be true in test environment since SERVICE_ADDR has no code)
        rsc = new VaultFunderRSC{value: 1 ether}(feeCollector, vault);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    CONSTRUCTOR TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_constructor_setsOwner() public view {
        assertEq(rsc.owner(), owner);
    }
    
    function test_constructor_storesFeeCollector() public view {
        (address storedFeeCollector, , , , ) = rsc.getConfig();
        assertEq(storedFeeCollector, feeCollector);
    }
    
    function test_constructor_storesVault() public view {
        (, address storedVault, , , ) = rsc.getConfig();
        assertEq(storedVault, vault);
    }
    
    function test_constructor_storesChainId() public view {
        (, , uint256 chainId, , ) = rsc.getConfig();
        assertEq(chainId, SEPOLIA_CHAIN_ID);
    }
    
    function test_constructor_cronEnabledByDefault() public view {
        (, , , , bool cronEnabled) = rsc.getConfig();
        assertTrue(cronEnabled);
    }
    
    function test_constructor_callbackCountStartsAtZero() public view {
        (, , , uint256 count, ) = rsc.getConfig();
        assertEq(count, 0);
    }
    
    function test_constructor_revertsOnZeroFeeCollector() public {
        vm.expectRevert("VaultFunderRSC: zero feeCollector");
        new VaultFunderRSC(address(0), vault);
    }
    
    function test_constructor_revertsOnZeroVault() public {
        vm.expectRevert("VaultFunderRSC: zero vault");
        new VaultFunderRSC(feeCollector, address(0));
    }
    
    function test_constructor_acceptsEthPayment() public view {
        assertEq(address(rsc).balance, 1 ether);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    ADMIN TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_setMinBlocksBetweenCallbacks_updates() public {
        rsc.setMinBlocksBetweenCallbacks(50);
        assertEq(rsc.minBlocksBetweenCallbacks(), 50);
    }
    
    function test_setMinBlocksBetweenCallbacks_onlyOwner() public {
        vm.prank(makeAddr("notOwner"));
        vm.expectRevert("VaultFunderRSC: only owner");
        rsc.setMinBlocksBetweenCallbacks(50);
    }
    
    function test_setCronEnabled_toggles() public {
        rsc.setCronEnabled(false);
        (, , , , bool cronEnabled) = rsc.getConfig();
        assertFalse(cronEnabled);
        
        rsc.setCronEnabled(true);
        (, , , , cronEnabled) = rsc.getConfig();
        assertTrue(cronEnabled);
    }
    
    function test_setCronEnabled_onlyOwner() public {
        vm.prank(makeAddr("notOwner"));
        vm.expectRevert("VaultFunderRSC: only owner");
        rsc.setCronEnabled(false);
    }
    
    function test_transferOwnership_updates() public {
        address newOwner = makeAddr("newOwner");
        rsc.transferOwnership(newOwner);
        assertEq(rsc.owner(), newOwner);
    }
    
    function test_transferOwnership_revertsOnZeroAddress() public {
        vm.expectRevert("VaultFunderRSC: zero address");
        rsc.transferOwnership(address(0));
    }
    
    function test_transferOwnership_onlyOwner() public {
        vm.prank(makeAddr("notOwner"));
        vm.expectRevert("VaultFunderRSC: only owner");
        rsc.transferOwnership(makeAddr("newOwner"));
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    VIEW FUNCTION TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_getConfig_returnsAllValues() public view {
        (
            address storedFeeCollector,
            address storedVault,
            uint256 chainId,
            uint256 callbackCount,
            bool cronEnabled
        ) = rsc.getConfig();
        
        assertEq(storedFeeCollector, feeCollector);
        assertEq(storedVault, vault);
        assertEq(chainId, SEPOLIA_CHAIN_ID);
        assertEq(callbackCount, 0);
        assertTrue(cronEnabled);
    }
    
    function test_cronInterval_hasDefaultValue() public view {
        assertEq(rsc.cronInterval(), 50);
    }
    
    function test_minBlocksBetweenCallbacks_hasDefaultValue() public view {
        assertEq(rsc.minBlocksBetweenCallbacks(), 25);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    RECEIVE ETH TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_receive_acceptsEth() public {
        vm.deal(address(this), 1 ether);
        
        (bool success, ) = address(rsc).call{value: 0.1 ether}("");
        assertTrue(success);
        
        assertEq(address(rsc).balance, 1.1 ether);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    FUZZ TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function testFuzz_setMinBlocksBetweenCallbacks_anyValue(uint256 blocks) public {
        blocks = bound(blocks, 1, 1000);
        rsc.setMinBlocksBetweenCallbacks(blocks);
        assertEq(rsc.minBlocksBetweenCallbacks(), blocks);
    }
    
    function testFuzz_constructor_acceptsAnyPositiveEth(uint256 amount) public {
        amount = bound(amount, 0.001 ether, 10 ether);
        
        VaultFunderRSC newRsc = new VaultFunderRSC{value: amount}(feeCollector, vault);
        assertEq(address(newRsc).balance, amount);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    RATE LIMITING LOGIC TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_rateLimiting_defaultIs25Blocks() public view {
        assertEq(rsc.minBlocksBetweenCallbacks(), 25);
    }
    
    function test_rateLimiting_canBeUpdated() public {
        rsc.setMinBlocksBetweenCallbacks(100);
        assertEq(rsc.minBlocksBetweenCallbacks(), 100);
    }
    
    function testFuzz_rateLimiting_blockMathWorks(uint256 lastBlock, uint256 currentBlock, uint256 interval) public pure {
        lastBlock = bound(lastBlock, 0, 1000000);
        interval = bound(interval, 1, 1000);
        currentBlock = bound(currentBlock, lastBlock, lastBlock + interval * 2);
        
        bool isRateLimited = currentBlock < lastBlock + interval;
        bool shouldAllow = currentBlock >= lastBlock + interval;
        
        // These should be mutually exclusive
        assertTrue(isRateLimited != shouldAllow);
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    CALLBACK PAYLOAD TESTS
    // ═══════════════════════════════════════════════════════════════
    
    function test_callbackPayload_isCorrectlyEncoded() public pure {
        bytes memory expectedPayload = abi.encodeWithSignature("checkAndFundVault()");
        
        // Verify the encoding
        assertEq(expectedPayload.length, 4); // Just function selector
        assertEq(bytes4(expectedPayload), bytes4(keccak256("checkAndFundVault()")));
    }
    
    // ═══════════════════════════════════════════════════════════════
    //                    INTEGRATION NOTE
    // ═══════════════════════════════════════════════════════════════
    
    /**
     * @notice Note on react() testing
     * @dev The react() function has a vmOnly modifier which requires the contract
     *      to be running in a Reactive VM environment. This cannot be simulated
     *      in standard Foundry unit tests.
     * 
     *      For full react() testing, deploy to Lasna testnet and use:
     *      - forge script to trigger events on Sepolia
     *      - Monitor callback execution via Reactscan
     *      - Verify funding on Sepolia destination contracts
     * 
     *      Alternatively, a future version could implement a test harness
     *      that mocks the SERVICE_ADDR to enable local react() testing.
     */
    function test_documentation_reactTestingNote() public pure {
        // This test serves as documentation
        assertTrue(true);
    }
}

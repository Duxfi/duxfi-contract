**THIS CHECKLIST IS NOT COMPLETE**. Use `--show-ignored-findings` to show all the results.
Summary
 - [weak-prng](#weak-prng) (1 results) (High)
 - [incorrect-equality](#incorrect-equality) (4 results) (Medium)
 - [reentrancy-no-eth](#reentrancy-no-eth) (2 results) (Medium)
 - [uninitialized-local](#uninitialized-local) (2 results) (Medium)
 - [unused-return](#unused-return) (2 results) (Medium)
 - [shadowing-local](#shadowing-local) (5 results) (Low)
 - [events-maths](#events-maths) (1 results) (Low)
 - [missing-zero-check](#missing-zero-check) (1 results) (Low)
 - [calls-loop](#calls-loop) (4 results) (Low)
 - [reentrancy-benign](#reentrancy-benign) (3 results) (Low)
 - [reentrancy-events](#reentrancy-events) (1 results) (Low)
 - [timestamp](#timestamp) (6 results) (Low)
 - [assembly](#assembly) (2 results) (Informational)
 - [pragma](#pragma) (1 results) (Informational)
 - [costly-loop](#costly-loop) (2 results) (Informational)
 - [solc-version](#solc-version) (3 results) (Informational)
 - [low-level-calls](#low-level-calls) (1 results) (Informational)
 - [missing-inheritance](#missing-inheritance) (1 results) (Informational)
 - [naming-convention](#naming-convention) (16 results) (Informational)
 - [too-many-digits](#too-many-digits) (1 results) (Informational)
 - [unimplemented-functions](#unimplemented-functions) (1 results) (Informational)
## weak-prng
Impact: High
Confidence: Medium
 - [ ] ID-0
[DuxTWAPOracleLibrary.currentBlockTimestamp()](.src/periphery/libraries/DuxTWAPOracleLibrary.sol#L11-L13) uses a weak PRNG: "[uint32(block.timestamp % 2 ** 32)](.src/periphery/libraries/DuxTWAPOracleLibrary.sol#L12)" 

.src/periphery/libraries/DuxTWAPOracleLibrary.sol#L11-L13


## incorrect-equality
Impact: Medium
Confidence: High
 - [ ] ID-1
[DuxPair.swap(uint256,uint256,address,bytes)](.src/core/DuxPair.sol#L190-L236) uses a dangerous strict equality:
	- [amount0In == 0 && amount1In == 0](.src/core/DuxPair.sol#L224)

.src/core/DuxPair.sol#L190-L236


 - [ ] ID-2
[DuxPair.mintLpToken(address)](.src/core/DuxPair.sol#L131-L158) uses a dangerous strict equality:
	- [_totalSupply == 0](.src/core/DuxPair.sol#L139)

.src/core/DuxPair.sol#L131-L158


 - [ ] ID-3
[DuxPair.mintLpToken(address)](.src/core/DuxPair.sol#L131-L158) uses a dangerous strict equality:
	- [lpToken == 0](.src/core/DuxPair.sol#L153)

.src/core/DuxPair.sol#L131-L158


 - [ ] ID-4
[DuxPair.burnLpToken(address)](.src/core/DuxPair.sol#L166-L188) uses a dangerous strict equality:
	- [_totalSupply == 0](.src/core/DuxPair.sol#L168)

.src/core/DuxPair.sol#L166-L188


## reentrancy-no-eth
Impact: Medium
Confidence: Medium
 - [ ] ID-5
Reentrancy in [DuxFactory.createPair(address,address,uint16,address)](.src/core/DuxFactory.sol#L47-L68):
	External calls:
	- [IDuxPair(pair).initialize(token0,token1,swapFeeBps)](.src/core/DuxFactory.sol#L63)
	State variables written after the call(s):
	- [getPair[token0][token1] = pair](.src/core/DuxFactory.sol#L64)
	[DuxFactory.getPair](.src/core/DuxFactory.sol#L33) can be used in cross function reentrancies:
	- [DuxFactory.createPair(address,address,uint16,address)](.src/core/DuxFactory.sol#L47-L68)
	- [DuxFactory.getPair](.src/core/DuxFactory.sol#L33)
	- [DuxFactory.getPairByTokens(address,address)](.src/core/DuxFactory.sol#L123-L129)
	- [DuxFactory.pairExists(address,address)](.src/core/DuxFactory.sol#L138-L142)
	- [DuxFactory.pausePair(address,address)](.src/core/DuxFactory.sol#L75-L78)
	- [DuxFactory.unpausePair(address,address)](.src/core/DuxFactory.sol#L85-L88)
	- [getPair[token1][token0] = pair](.src/core/DuxFactory.sol#L65)
	[DuxFactory.getPair](.src/core/DuxFactory.sol#L33) can be used in cross function reentrancies:
	- [DuxFactory.createPair(address,address,uint16,address)](.src/core/DuxFactory.sol#L47-L68)
	- [DuxFactory.getPair](.src/core/DuxFactory.sol#L33)
	- [DuxFactory.getPairByTokens(address,address)](.src/core/DuxFactory.sol#L123-L129)
	- [DuxFactory.pairExists(address,address)](.src/core/DuxFactory.sol#L138-L142)
	- [DuxFactory.pausePair(address,address)](.src/core/DuxFactory.sol#L75-L78)
	- [DuxFactory.unpausePair(address,address)](.src/core/DuxFactory.sol#L85-L88)

.src/core/DuxFactory.sol#L47-L68


 - [ ] ID-6
Reentrancy in [DuxPair.swap(uint256,uint256,address,bytes)](.src/core/DuxPair.sol#L190-L236):
	External calls:
	- [IERC20(token0).safeTransfer(to,amount0Out)](.src/core/DuxPair.sol#L209)
	- [IERC20(token1).safeTransfer(to,amount1Out)](.src/core/DuxPair.sol#L212)
	- [IDuxCallee(to).duxCall(msg.sender,amount0Out,amount1Out,data)](.src/core/DuxPair.sol#L216)
	State variables written after the call(s):
	- [_syncPoolState(uint256(balance0),uint256(balance1))](.src/core/DuxPair.sol#L234)
		- [reserve0 = uint112(_newReserve0)](.src/core/DuxPair.sol#L273)
	[DuxPair.reserve0](.src/core/DuxPair.sol#L58) can be used in cross function reentrancies:
	- [DuxPair.getReserves()](.src/core/DuxPair.sol#L290-L294)
	- [DuxPair.getReservesWithFee()](.src/core/DuxPair.sol#L318-L322)
	- [_syncPoolState(uint256(balance0),uint256(balance1))](.src/core/DuxPair.sol#L234)
		- [reserve1 = uint112(_newReserve1)](.src/core/DuxPair.sol#L275)
	[DuxPair.reserve1](.src/core/DuxPair.sol#L59) can be used in cross function reentrancies:
	- [DuxPair.getReserves()](.src/core/DuxPair.sol#L290-L294)
	- [DuxPair.getReservesWithFee()](.src/core/DuxPair.sol#L318-L322)

.src/core/DuxPair.sol#L190-L236


## uninitialized-local
Impact: Medium
Confidence: Medium
 - [ ] ID-7
[DuxRouter._sortTokenAndCalculateOptimalLiquidity(address,uint256,uint256,address).amount1Desired](.src/periphery/DuxRouter.sol#L231) is a local variable never initialized

.src/periphery/DuxRouter.sol#L231


 - [ ] ID-8
[DuxRouter._sortTokenAndCalculateOptimalLiquidity(address,uint256,uint256,address).amount0Desired](.src/periphery/DuxRouter.sol#L230) is a local variable never initialized

.src/periphery/DuxRouter.sol#L230


## unused-return
Impact: Medium
Confidence: Medium
 - [ ] ID-9
[DuxRouter._sortTokenAndCalculateOptimalLiquidity(address,uint256,uint256,address)](.src/periphery/DuxRouter.sol#L223-L258) ignores return value by [(_r0,_r1,None) = _duxPair.getReserves()](.src/periphery/DuxRouter.sol#L229)

.src/periphery/DuxRouter.sol#L223-L258


 - [ ] ID-10
[DuxRouter._swap(uint256[],address[],address,address[])](.src/periphery/DuxRouter.sol#L268-L290) ignores return value by [(token0,None) = DuxLibrary.sortTokens(path[i],path[i + 1])](.src/periphery/DuxRouter.sol#L275)

.src/periphery/DuxRouter.sol#L268-L290


## shadowing-local
Impact: Low
Confidence: High
 - [ ] ID-11
[DuxPair.burnLpToken(address)._totalSupply](.src/core/DuxPair.sol#L167) shadows:
	- [ERC20._totalSupply](.lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol#L40) (state variable)

.src/core/DuxPair.sol#L167


 - [ ] ID-12
[DuCoin.constructor(string,string,uint8).name](.src/core/DuCoin.sol#L16) shadows:
	- [ERC20.name()](.lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol#L62-L64) (function)
	- [IERC20Metadata.name()](.lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol#L17) (function)

.src/core/DuCoin.sol#L16


 - [ ] ID-13
[DuxPair.mintLpToken(address)._totalSupply](.src/core/DuxPair.sol#L138) shadows:
	- [ERC20._totalSupply](.lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol#L40) (state variable)

.src/core/DuxPair.sol#L138


 - [ ] ID-14
[DuxPair._syncPoolState(uint256,uint256)._totalSupply](.src/core/DuxPair.sol#L277) shadows:
	- [ERC20._totalSupply](.lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol#L40) (state variable)

.src/core/DuxPair.sol#L277


 - [ ] ID-15
[DuCoin.constructor(string,string,uint8).symbol](.src/core/DuCoin.sol#L16) shadows:
	- [ERC20.symbol()](.lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol#L70-L72) (function)
	- [IERC20Metadata.symbol()](.lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol#L22) (function)

.src/core/DuCoin.sol#L16


## events-maths
Impact: Low
Confidence: Medium
 - [ ] ID-16
[DuxPair.initialize(address,address,uint16)](.src/core/DuxPair.sol#L110-L119) should emit an event for: 
	- [swapFeeBps = _swapFeeBps](.src/core/DuxPair.sol#L117) 

.src/core/DuxPair.sol#L110-L119


## missing-zero-check
Impact: Low
Confidence: Medium
 - [ ] ID-17
[DuxRouter.constructor(address)._factory](.src/periphery/DuxRouter.sol#L62) lacks a zero-check on :
		- [FACTORY = _factory](.src/periphery/DuxRouter.sol#L63)

.src/periphery/DuxRouter.sol#L62


## calls-loop
Impact: Low
Confidence: Medium
 - [ ] ID-18
[DuxFaucet.claimDaily()](.src/periphery/DuxFaucet.sol#L132-L149) has external calls inside a loop: [IDuCoin(token).mint(msg.sender,amt)](.src/periphery/DuxFaucet.sol#L144)

.src/periphery/DuxFaucet.sol#L132-L149


 - [ ] ID-19
[DuxRouter._swap(uint256[],address[],address,address[])](.src/periphery/DuxRouter.sol#L268-L290) has external calls inside a loop: [IDuxPair(pairs[i]).swap(amount0Out,amount1Out,recipient,)](.src/periphery/DuxRouter.sol#L287)
	Calls stack containing the loop:
		DuxRouter.swapExactTokensForTokens(uint256,uint256,address[],address,uint256)

.src/periphery/DuxRouter.sol#L268-L290


 - [ ] ID-20
[DuxFactory.pauseAllPairs()](.src/core/DuxFactory.sol#L93-L101) has external calls inside a loop: [IDuxPair(allPairs[i]).pause()](.src/core/DuxFactory.sol#L96)

.src/core/DuxFactory.sol#L93-L101


 - [ ] ID-21
[DuxFactory.unpauseAllPairs()](.src/core/DuxFactory.sol#L106-L114) has external calls inside a loop: [IDuxPair(allPairs[i]).unpause()](.src/core/DuxFactory.sol#L109)

.src/core/DuxFactory.sol#L106-L114


## reentrancy-benign
Impact: Low
Confidence: Medium
 - [ ] ID-22
Reentrancy in [DuxPair.burnLpToken(address)](.src/core/DuxPair.sol#L166-L188):
	External calls:
	- [IERC20(token0).safeTransfer(to,amount0)](.src/core/DuxPair.sol#L180)
	- [IERC20(token1).safeTransfer(to,amount1)](.src/core/DuxPair.sol#L181)
	State variables written after the call(s):
	- [_syncPoolState(uint256(balance0),uint256(balance1))](.src/core/DuxPair.sol#L185)
		- [blockTimestampLast = blockTimestamp](.src/core/DuxPair.sol#L276)
	- [_syncPoolState(uint256(balance0),uint256(balance1))](.src/core/DuxPair.sol#L185)
		- [price0CumulativeLast += uint256(FixedPoint.fraction(_reserve1,_reserve0)._x) * timeElapsed](.src/core/DuxPair.sol#L266)
	- [_syncPoolState(uint256(balance0),uint256(balance1))](.src/core/DuxPair.sol#L185)
		- [price1CumulativeLast += uint256(FixedPoint.fraction(_reserve0,_reserve1)._x) * timeElapsed](.src/core/DuxPair.sol#L267)
	- [_syncPoolState(uint256(balance0),uint256(balance1))](.src/core/DuxPair.sol#L185)
		- [reserve0 = uint112(_newReserve0)](.src/core/DuxPair.sol#L273)
	- [_syncPoolState(uint256(balance0),uint256(balance1))](.src/core/DuxPair.sol#L185)
		- [reserve1 = uint112(_newReserve1)](.src/core/DuxPair.sol#L275)

.src/core/DuxPair.sol#L166-L188


 - [ ] ID-23
Reentrancy in [DuxPair.swap(uint256,uint256,address,bytes)](.src/core/DuxPair.sol#L190-L236):
	External calls:
	- [IERC20(token0).safeTransfer(to,amount0Out)](.src/core/DuxPair.sol#L209)
	- [IERC20(token1).safeTransfer(to,amount1Out)](.src/core/DuxPair.sol#L212)
	- [IDuxCallee(to).duxCall(msg.sender,amount0Out,amount1Out,data)](.src/core/DuxPair.sol#L216)
	State variables written after the call(s):
	- [_syncPoolState(uint256(balance0),uint256(balance1))](.src/core/DuxPair.sol#L234)
		- [blockTimestampLast = blockTimestamp](.src/core/DuxPair.sol#L276)
	- [_syncPoolState(uint256(balance0),uint256(balance1))](.src/core/DuxPair.sol#L234)
		- [price0CumulativeLast += uint256(FixedPoint.fraction(_reserve1,_reserve0)._x) * timeElapsed](.src/core/DuxPair.sol#L266)
	- [_syncPoolState(uint256(balance0),uint256(balance1))](.src/core/DuxPair.sol#L234)
		- [price1CumulativeLast += uint256(FixedPoint.fraction(_reserve0,_reserve1)._x) * timeElapsed](.src/core/DuxPair.sol#L267)

.src/core/DuxPair.sol#L190-L236


 - [ ] ID-24
Reentrancy in [DuxFactory.createPair(address,address,uint16,address)](.src/core/DuxFactory.sol#L47-L68):
	External calls:
	- [IDuxPair(pair).initialize(token0,token1,swapFeeBps)](.src/core/DuxFactory.sol#L63)
	State variables written after the call(s):
	- [allPairs.push(pair)](.src/core/DuxFactory.sol#L66)

.src/core/DuxFactory.sol#L47-L68


## reentrancy-events
Impact: Low
Confidence: Medium
 - [ ] ID-25
Reentrancy in [DuxFactory.createPair(address,address,uint16,address)](.src/core/DuxFactory.sol#L47-L68):
	External calls:
	- [IDuxPair(pair).initialize(token0,token1,swapFeeBps)](.src/core/DuxFactory.sol#L63)
	Event emitted after the call(s):
	- [PairCreated(token0,token1,pair,creator)](.src/core/DuxFactory.sol#L67)

.src/core/DuxFactory.sol#L47-L68


## timestamp
Impact: Low
Confidence: Medium
 - [ ] ID-26
[DuxRouter._ensure(uint256)](.src/periphery/DuxRouter.sol#L55-L57) uses timestamp for comparisons
	Dangerous comparisons:
	- [block.timestamp > deadline](.src/periphery/DuxRouter.sol#L56)

.src/periphery/DuxRouter.sol#L55-L57


 - [ ] ID-27
[DuxPair.mintLpToken(address)](.src/core/DuxPair.sol#L131-L158) uses timestamp for comparisons
	Dangerous comparisons:
	- [_totalSupply == 0](.src/core/DuxPair.sol#L139)
	- [initLiq <= MINIMUM_LIQUIDITY](.src/core/DuxPair.sol#L142)
	- [lpToken == 0](.src/core/DuxPair.sol#L153)

.src/core/DuxPair.sol#L131-L158


 - [ ] ID-28
[DuxTWAPOracleLibrary.currentCumulativePrices(address)](.src/periphery/libraries/DuxTWAPOracleLibrary.sol#L22-L40) uses timestamp for comparisons
	Dangerous comparisons:
	- [blockTimestampLast != blockTimestamp](.src/periphery/libraries/DuxTWAPOracleLibrary.sol#L32)

.src/periphery/libraries/DuxTWAPOracleLibrary.sol#L22-L40


 - [ ] ID-29
[DuxFaucet.claimDaily()](.src/periphery/DuxFaucet.sol#L132-L149) uses timestamp for comparisons
	Dangerous comparisons:
	- [require(bool,string)(block.timestamp - lastDailyClaimTime[msg.sender] >= claimCooldown,Already claimed in cooldown period)](.src/periphery/DuxFaucet.sol#L133)

.src/periphery/DuxFaucet.sol#L132-L149


 - [ ] ID-30
[DuxPair.burnLpToken(address)](.src/core/DuxPair.sol#L166-L188) uses timestamp for comparisons
	Dangerous comparisons:
	- [_totalSupply == 0](.src/core/DuxPair.sol#L168)

.src/core/DuxPair.sol#L166-L188


 - [ ] ID-31
[DuxPair._syncPoolState(uint256,uint256)](.src/core/DuxPair.sol#L258-L279) uses timestamp for comparisons
	Dangerous comparisons:
	- [timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0](.src/core/DuxPair.sol#L264)

.src/core/DuxPair.sol#L258-L279


## assembly
Impact: Informational
Confidence: High
 - [ ] ID-32
[DuxFactory._efficientHash(address,address)](.src/core/DuxFactory.sol#L158-L166) uses assembly
	- [INLINE ASM](.src/core/DuxFactory.sol#L159-L165)

.src/core/DuxFactory.sol#L158-L166


 - [ ] ID-33
[DuxFactory.createPair(address,address,uint16,address)](.src/core/DuxFactory.sol#L47-L68) uses assembly
	- [INLINE ASM](.src/core/DuxFactory.sol#L59-L61)

.src/core/DuxFactory.sol#L47-L68


## pragma
Impact: Informational
Confidence: High
 - [ ] ID-34
4 different versions of Solidity are used:
	- Version constraint ^0.8.0 is used by:
		-[^0.8.0](.lib/openzeppelin-contracts/contracts/access/Ownable.sol#L4)
		-[^0.8.0](.lib/openzeppelin-contracts/contracts/security/Pausable.sol#L4)
		-[^0.8.0](.lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol#L4)
		-[^0.8.0](.lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol#L4)
		-[^0.8.0](.lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol#L4)
		-[^0.8.0](.lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol#L4)
		-[^0.8.0](.lib/openzeppelin-contracts/contracts/token/ERC20/extensions/draft-IERC20Permit.sol#L4)
		-[^0.8.0](.lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol#L4)
		-[^0.8.0](.lib/openzeppelin-contracts/contracts/utils/Context.sol#L4)
		-[^0.8.0](.src/core/interfaces/IDuxCallee.sol#L2)
	- Version constraint ^0.8.1 is used by:
		-[^0.8.1](.lib/openzeppelin-contracts/contracts/utils/Address.sol#L4)
	- Version constraint ^0.8.19 is used by:
		-[^0.8.19](.src/core/DuCoin.sol#L2)
		-[^0.8.19](.src/core/DuxFactory.sol#L2)
		-[^0.8.19](.src/core/DuxPair.sol#L2)
		-[^0.8.19](.src/core/interfaces/IDuxFactory.sol#L2)
		-[^0.8.19](.src/core/interfaces/IDuxPair.sol#L2)
		-[^0.8.19](.src/periphery/DuxFaucet.sol#L2)
		-[^0.8.19](.src/periphery/DuxRouter.sol#L2)
		-[^0.8.19](.src/periphery/interfaces/IDuxRouter.sol#L2)
		-[^0.8.19](.src/periphery/libraries/DuxLibrary.sol#L3)
		-[^0.8.19](.src/periphery/libraries/DuxTWAPOracleLibrary.sol#L3)
	- Version constraint 0.8.19 is used by:
		-[0.8.19](.src/core/libraries/Math.sol#L2)
		-[0.8.19](.src/libraries/FixedPoint.sol#L2)

.lib/openzeppelin-contracts/contracts/access/Ownable.sol#L4


## costly-loop
Impact: Informational
Confidence: Medium
 - [ ] ID-35
[DuxFaucet.removeToken(address)](.src/periphery/DuxFaucet.sol#L64-L77) has costly operations inside a loop:
	- [tokens.pop()](.src/periphery/DuxFaucet.sol#L71)

.src/periphery/DuxFaucet.sol#L64-L77


 - [ ] ID-36
[DuxFaucet.clearAllTokens()](.src/periphery/DuxFaucet.sol#L109-L118) has costly operations inside a loop:
	- [delete dailyAmounts[token]](.src/periphery/DuxFaucet.sol#L113)

.src/periphery/DuxFaucet.sol#L109-L118


## solc-version
Impact: Informational
Confidence: High
 - [ ] ID-37
Version constraint 0.8.19 contains known severe issues (https://solidity.readthedocs.io/en/latest/bugs.html)
	- VerbatimInvalidDeduplication
	- FullInlinerNonExpressionSplitArgumentEvaluationOrder
	- MissingSideEffectsOnSelectorAccess.
It is used by:
	- [0.8.19](.src/core/libraries/Math.sol#L2)
	- [0.8.19](.src/libraries/FixedPoint.sol#L2)

.src/core/libraries/Math.sol#L2


 - [ ] ID-38
Version constraint ^0.8.19 contains known severe issues (https://solidity.readthedocs.io/en/latest/bugs.html)
	- VerbatimInvalidDeduplication
	- FullInlinerNonExpressionSplitArgumentEvaluationOrder
	- MissingSideEffectsOnSelectorAccess.
It is used by:
	- [^0.8.19](.src/core/DuCoin.sol#L2)
	- [^0.8.19](.src/core/DuxFactory.sol#L2)
	- [^0.8.19](.src/core/DuxPair.sol#L2)
	- [^0.8.19](.src/core/interfaces/IDuxFactory.sol#L2)
	- [^0.8.19](.src/core/interfaces/IDuxPair.sol#L2)
	- [^0.8.19](.src/periphery/DuxFaucet.sol#L2)
	- [^0.8.19](.src/periphery/DuxRouter.sol#L2)
	- [^0.8.19](.src/periphery/interfaces/IDuxRouter.sol#L2)
	- [^0.8.19](.src/periphery/libraries/DuxLibrary.sol#L3)
	- [^0.8.19](.src/periphery/libraries/DuxTWAPOracleLibrary.sol#L3)

.src/core/DuCoin.sol#L2


 - [ ] ID-39
Version constraint ^0.8.0 contains known severe issues (https://solidity.readthedocs.io/en/latest/bugs.html)
	- FullInlinerNonExpressionSplitArgumentEvaluationOrder
	- MissingSideEffectsOnSelectorAccess
	- AbiReencodingHeadOverflowWithStaticArrayCleanup
	- DirtyBytesArrayToStorage
	- DataLocationChangeInInternalOverride
	- NestedCalldataArrayAbiReencodingSizeValidation
	- SignedImmutables
	- ABIDecodeTwoDimensionalArrayMemory
	- KeccakCaching.
It is used by:
	- [^0.8.0](.lib/openzeppelin-contracts/contracts/access/Ownable.sol#L4)
	- [^0.8.0](.lib/openzeppelin-contracts/contracts/security/Pausable.sol#L4)
	- [^0.8.0](.lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol#L4)
	- [^0.8.0](.lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol#L4)
	- [^0.8.0](.lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol#L4)
	- [^0.8.0](.lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol#L4)
	- [^0.8.0](.lib/openzeppelin-contracts/contracts/token/ERC20/extensions/draft-IERC20Permit.sol#L4)
	- [^0.8.0](.lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol#L4)
	- [^0.8.0](.lib/openzeppelin-contracts/contracts/utils/Context.sol#L4)
	- [^0.8.0](.src/core/interfaces/IDuxCallee.sol#L2)

.lib/openzeppelin-contracts/contracts/access/Ownable.sol#L4


## low-level-calls
Impact: Informational
Confidence: High
 - [ ] ID-40
Low level call in [DuxFaucet.withdrawETH()](.src/periphery/DuxFaucet.sol#L159-L164):
	- [(ok,None) = address(owner()).call{value: balance}()](.src/periphery/DuxFaucet.sol#L162)

.src/periphery/DuxFaucet.sol#L159-L164


## missing-inheritance
Impact: Informational
Confidence: High
 - [ ] ID-41
[DuCoin](.src/core/DuCoin.sol#L7-L52) should inherit from [IDuCoin](.src/periphery/DuxFaucet.sol#L10-L12)

.src/core/DuCoin.sol#L7-L52


## naming-convention
Impact: Informational
Confidence: High
 - [ ] ID-42
Parameter [DuxFaucet.withdrawERC20(address,uint256)._token](.src/periphery/DuxFaucet.sol#L166) is not in mixedCase

.src/periphery/DuxFaucet.sol#L166


 - [ ] ID-43
Function [IDuxFactory.MAX_SWAP_FEE_BPS()](.src/core/interfaces/IDuxFactory.sol#L6) is not in mixedCase

.src/core/interfaces/IDuxFactory.sol#L6


 - [ ] ID-44
Parameter [DuxFaucet.setCooldown(uint256)._newCooldown](.src/periphery/DuxFaucet.sol#L123) is not in mixedCase

.src/periphery/DuxFaucet.sol#L123


 - [ ] ID-45
Parameter [DuxPair.initialize(address,address,uint16)._swapFeeBps](.src/core/DuxPair.sol#L110) is not in mixedCase

.src/core/DuxPair.sol#L110


 - [ ] ID-46
Variable [DuxPair.FACTORY](.src/core/DuxPair.sol#L52) is not in mixedCase

.src/core/DuxPair.sol#L52


 - [ ] ID-47
Parameter [DuxFaucet.updateTokenAmount(address,uint256)._token](.src/periphery/DuxFaucet.sol#L84) is not in mixedCase

.src/periphery/DuxFaucet.sol#L84


 - [ ] ID-48
Variable [DuxRouter.FACTORY](.src/periphery/DuxRouter.sol#L37) is not in mixedCase

.src/periphery/DuxRouter.sol#L37


 - [ ] ID-49
Parameter [DuxFaucet.removeToken(address)._token](.src/periphery/DuxFaucet.sol#L64) is not in mixedCase

.src/periphery/DuxFaucet.sol#L64


 - [ ] ID-50
Struct [FixedPoint.uq112x112](.src/libraries/FixedPoint.sol#L12-L14) is not in CapWords

.src/libraries/FixedPoint.sol#L12-L14


 - [ ] ID-51
Parameter [DuxPair.initialize(address,address,uint16)._token1](.src/core/DuxPair.sol#L110) is not in mixedCase

.src/core/DuxPair.sol#L110


 - [ ] ID-52
Parameter [DuxFaucet.updateTokenAmount(address,uint256)._newAmount](.src/periphery/DuxFaucet.sol#L84) is not in mixedCase

.src/periphery/DuxFaucet.sol#L84


 - [ ] ID-53
Variable [DuCoin.DECIMALS](.src/core/DuCoin.sol#L8) is not in mixedCase

.src/core/DuCoin.sol#L8


 - [ ] ID-54
Parameter [DuxPair.initialize(address,address,uint16)._token2](.src/core/DuxPair.sol#L110) is not in mixedCase

.src/core/DuxPair.sol#L110


 - [ ] ID-55
Parameter [DuxFaucet.withdrawERC20(address,uint256)._amount](.src/periphery/DuxFaucet.sol#L166) is not in mixedCase

.src/periphery/DuxFaucet.sol#L166


 - [ ] ID-56
Parameter [DuxFaucet.setTokens(address[],uint256[])._dailyAmounts](.src/periphery/DuxFaucet.sol#L45) is not in mixedCase

.src/periphery/DuxFaucet.sol#L45


 - [ ] ID-57
Parameter [DuxFaucet.setTokens(address[],uint256[])._tokens](.src/periphery/DuxFaucet.sol#L45) is not in mixedCase

.src/periphery/DuxFaucet.sol#L45


## too-many-digits
Impact: Informational
Confidence: Medium
 - [ ] ID-58
[DuxFactory.createPair(address,address,uint16,address)](.src/core/DuxFactory.sol#L47-L68) uses literals with too many digits:
	- [bytecode = type()(DuxPair).creationCode](.src/core/DuxFactory.sol#L56)

.src/core/DuxFactory.sol#L47-L68


## unimplemented-functions
Impact: Informational
Confidence: High
 - [ ] ID-59
[DuxPair](.src/core/DuxPair.sol#L20-L354) does not implement functions:
	- [IDuxPair.transferFrom(address,address,uint256)](.src/core/interfaces/IDuxPair.sol#L91)

.src/core/DuxPair.sol#L20-L354



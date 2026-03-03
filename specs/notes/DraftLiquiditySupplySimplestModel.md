# Intent


1. Build model
### Model Assumptions


> The model transitions are not indexed by time BUT by swaps

Then the model life time is the number of swaps 


------------------
From here we define
type LiquiditySupplyModelSimplestTest extends PosmTestSetUp::
     setUp()
     R1.3  initialization includes token Approval of routers, etx
     R1.4  The traders do not have identity, they are address(this) on tests,
     address constant TRADER = adddres(this)
     '''
     this is beacuase we = do not care on their dynamics
     since we are assuming they are all the same (uninformed)
     '''

	
type LiquiditySupplyModelSimplest extends ToyCLAMM2Dir::
     Markets(marketKey);
	R1.1  Both markets MUST have the same underluyign AND unit of account
	R1.2. One of the tokens is a unit of account token (numeraire)

     TradingFLow(marketKey);

      Simplest ==> rules

     PerfectVolumeElasticityWrtLiquidityDepth
     '''
     expl: This is one of the results of JIT papaer from capponi
     sophisticated LP's maximize crowding out effects to passivle LP's when
     uninformed trading flow respond to LiquidityDepth
     '''
     
     FixedMarketPrice
     '''
     expl: For simplicity we assume that the CFMM is the primary market, this is because in this way
     there is no informed trading flow by construction.
     Note that this requirement can be modeled as a consequence of the following model rule

     For every successful TradeRequest whicch execution price is X units awy from the fixedPrice
     the subsequent successful TradeRequest MUST be such that executionPrice = fixedPrice,
     '''


1. PerfectVolumeElasticityWrtLiquidityDepth

This is a rule on the swap behavior the TRADER will follow in response ONLY to the LiquidityDpeth
Observed

This is


rule PerfectVolumeElasticityWrtLiquidityDepth(
	type LiquidityDepth(afterAddLiquidity OR event modifyLiquidity, StateLibrary)
	) --> SwapVolume 
	      
- more LiquidityDepth ==> more SwapVolume
- perfect elastic --> THIS IS WE NEED A DETERMINISTIN RULE FOR HOW SWAPVOLUME REACTS TO LIQUIDITY DPTH
THAT FULFILLS PERFECT ELASTICITY



This is

property perfectElastic(LiquidityDepth(beforeSwap), SwapVolume(afterSwap))

2. FIxedMeanMarketPrice

At high level:
struct FixedMeanMarketPrice{
       uint160 lastPrice
       PoolId referenceMarket
}

function poolId(FixedMarketPrice) returns(PoolId) 
function lastPrice(FixedMarketPrice) returns(uint160)

function fixedMarketPrice(PoolId){
	 require(StateLibrary.slot0(poolId()) == lastPrice())
}


This needs formal verification

type MeanRevertingVolume(vm.snapshot(state)):
     require(isInvese(swapDeltaPrevious, swapDeltaNow);


Then we are claiming the following construction rule

                               MeanRevertingVolume ===> FixedMarketPrice



CFMMIsOnlyMarket(Model,underlying(market))) ===> impermanentLoss(Model, underlying(market))) ==0 


> We assume a risk-free rate of 0 

This is becuase there is no other benchmark strategy to allocate cpital in this model than liquidity provision

Then the only cost for liquidity provision is operational (gas cost for rebalancing). Thus the
trading fee is bounded below by the LiquidityMintingANdBurnignGasCost

On our model the trading fee is 4*LiquidityMintingANdBurnignGasCost,

   This is 1 unit that for that finances the LiquidityMintingANdBurnignGasCost
   2 units that the JIT captures
   1 unit the JIT leaves as surplues to the PLP as payment for providing the liquidityDepth that
   attracted the tradingVolume



Then \phi = 4*max(LiquidityMintingAndBurningGasCost)

ElasticVolumeWrtLiquidityDepth ==> liquidityDepth_{t+1}(elasticity(volume_t, liquidityDepth_t))
									|
									|
							<---------------
			This is an update rule we must engineer

MeanRevertingVolume ==> JITALwaysWantsToRespondToSwap

'''
This is to be consistnent with JIT always wanting to capture the non-informed trading volume

     ==> JIT probability of arrival is always 1

UnawareSufficiency
	- The JIT does not know, but No swap can exceed JITLiquidityOnSwap
	'''
	This is to show the case where the LP sophisitcation is on  BOTH technology
	(ability to detect swaps on mempool) AND capital, meaning they alwsy have anough capital
	to fulfill UninformedTRading flow 

value(\sum (swaps)) <= value(representativeLPPosition) -> (invariant)

ModelState::
	InitialState(NoSwaps):
		LiquidityProviders(market): 
	 		count(LiquidityProviders,market)) = 4 (2 per pool)
							          |
								  -> 1 plp ^ 1 jit 
        ==> All liquidity providers have same initial capital

LiquidityProvider(type):
	Inventory: [underlying, cash]
	type: <PLP>; <JIT>;

	liquidity(ModelState(...); ...)

LiquidityProvider(<PLP>):
	
	liquidity(ModelState(...); elasticity(volume, liquidityDepth))	
	'''
	passive LP's provide liquidity that maxmizes the demand subject to the
        perfect elasticity only available information they know and budget constrain
	(inventory constrain)
	
	'''

LiquidityProvider(<JIT>)

	liquidity(ModelState(...), liquidityPLP, elasticity)
	'''
	jit LP's provide liquidity such thet they ALWAYS capture 2 units of fee and
	leave the plp 1 unit of surplus
	'''

MeanRevertingVolume  ==> MeanRevertingPrice ==>  ConstantTickSpread



 --> Each swap crosses the tickRange ==> triggers fee revenue collection
 '''
 This is to collect the fees on eacxh swap and thuis calculate markouts at each swap
 '''

--> After each swap a passive liquidity provider enters and adds liquidity such that its share MUST be the same as the others LP's

==> AT THE END THE NUMBER OF SWAPS PER POOL EAULS THE NUMBER OF LP'S + 2

--> The same behavor happens for both pools



==> In one pool ONE passive PLP has access to an instrument that pays
one unit of account per liquidity provider that enters the pool.


==> Result: The ONE PLP that uses the surplus share he has to buy the instrument while
the others LP's on both pools re-invest the surplus as liquidity


- Show that the PLP  hedges the competition risk

- Show that the competition risk is the only risk associated with passive liquidity provision in this model




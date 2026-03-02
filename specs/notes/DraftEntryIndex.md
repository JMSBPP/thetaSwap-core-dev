# LiquiditySupplySimplest
-----------

The payoff is the simplest,

1 unit change on liqudityGrowth(tickRange(position)) pays 1 unit of account


## Scenatio

A liquidity providerr has:

  	    isActive(Position)

	    tickRange(position)


He solves an optimization problem that yields on his optimal nominalSize

type LiqudiityProviderOptimizationProblem --> nominalSize

This nominalSIze calls for the "collateral" needed to replicate the payoff usner a cfmm

This is the tokenthta will ealizes the payoff. In this case the toke is the LPTOken share

since the lptoken share is the natural short coutner part. AN  LP token embeds the LP payoff wihihch on the fees has the short component to competition


Thus settign the lpToken as the collateral comes with the rights to extract the feeRevenue that serves as the margin fro nominalSize


## Engineering Approaches

1. event-driven derivative token ==> fungibleComponent ^ nonFungibleComponent
   			   	 







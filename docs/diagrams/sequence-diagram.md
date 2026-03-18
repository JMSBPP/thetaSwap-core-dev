# FCI Pool Listening Flow -- Sequence Diagram

This diagram traces the full lifecycle of FCI metric tracking. It begins with `listenPool()` to register a pool for monitoring, then shows how each swap triggers metric computation via delegatecall dispatch to the appropriate protocol facet, and concludes with an external reader querying the derived `DeltaPlus` value. Mint and burn operations follow the same delegatecall dispatch pattern with position-level accounting.

```mermaid
sequenceDiagram
    participant Caller as Caller (Pool Deployer)
    participant FCI as FCI V2 (Orchestrator)
    participant Facet as Protocol Facet (V4/V3)
    participant Reader as External Reader

    %% ── Part 1: Pool Registration ──
    rect rgb(204, 229, 255)
        Note over Caller,FCI: Pool Registration (one-time setup)
        Caller->>FCI: registerProtocolFacet(flags, facet)
        activate FCI
        FCI->>FCI: store facet address in registry
        deactivate FCI

        Caller->>FCI: listenPool(poolId, protocolFlags, hookData)
        activate FCI
        Note over FCI: Pool is now tracked.<br/>Maps poolId to protocolFlags.<br/>Initializes A_T = 0, N = 0.
        FCI->>Facet: delegatecall listen(hookData, poolId)
        activate Facet
        Facet-->>FCI: pool initialized in protocol storage
        deactivate Facet
        deactivate FCI
    end

    %% ── Part 2: Swap Flow (representative) ──
    rect rgb(212, 237, 218)
        Note over FCI,Facet: Per-swap metric computation (repeats every swap)

        Note over FCI: PoolManager calls beforeSwap()<br/>or UniswapV3Callback triggers it

        activate FCI
        FCI->>FCI: extract protocolFlags from hookData[0:2]

        Note over FCI: beforeSwap: store tickBefore via tstoreTick()
        FCI->>Facet: delegatecall currentTick(hookData, poolId)
        activate Facet
        Facet-->>FCI: tickBefore
        deactivate Facet

        FCI->>Facet: delegatecall tstoreTick(hookData, tickBefore)
        activate Facet
        Facet-->>FCI: tick stored in transient storage
        deactivate Facet

        Note over FCI: afterSwap callback fires

        FCI->>Facet: delegatecall tloadTick(hookData)
        activate Facet
        Note right of Facet: load tick before swap (tloadTick())
        Facet-->>FCI: tickBefore
        deactivate Facet

        FCI->>Facet: delegatecall currentTick(hookData, poolId)
        activate Facet
        Note right of Facet: read tick after swap (currentTick())
        Facet-->>FCI: tickAfter
        deactivate Facet

        FCI->>FCI: compute tick overlap interval<br/>sortTicks(tickBefore, tickAfter)

        FCI->>Facet: delegatecall incrementOverlappingRanges(<br/>hookData, poolId, tickMin, tickMax)
        activate Facet
        Note right of Facet: increment swapCount for<br/>all ranges spanning [tickMin, tickMax]
        Facet-->>FCI: ranges updated
        deactivate Facet

        Note over FCI: On position removal (afterRemoveLiquidity):<br/>FCI computes xk (FeeShareRatio),<br/>updates A_T accumulator,<br/>emits FCITermAccumulated event

        FCI->>Facet: delegatecall addStateTerm(<br/>hookData, poolId, blockLifetime, xSquaredQ128)
        activate Facet
        Note right of Facet: accumulate FCI state term
        Facet-->>FCI: A_T, ThetaSum updated
        deactivate Facet
        deactivate FCI
    end

    %% ── Part 3: External Query ──
    rect rgb(255, 243, 205)
        Note over Reader,FCI: External read (any time after accumulation)

        Reader->>FCI: getDeltaPlus(poolKey, flags)
        activate FCI
        FCI-->>Reader: DeltaPlus value (uint128)
        deactivate FCI

        Note over Reader: DeltaPlus = max(0, 1 - A_T)<br/>Used for insurance pricing<br/>and vault oracle payoff
    end

    Note over Caller,Reader: Mint/burn follow the same delegatecall pattern<br/>with position-level fee growth accounting
```

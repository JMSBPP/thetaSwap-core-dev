# Requirements: ThetaSwap Presentation

**Defined:** 2026-03-18
**Core Value:** Communicate that ThetaSwap builds the first on-chain adverse competition oracle enabling LP hedging — orthogonal to LVR

## v1 Requirements

### Problem Synthesis

- [ ] **PROB-01**: Presentation opens with the adverse competition problem — fee concentration is orthogonal to LVR, passive LPs face a risk no existing product hedges
- [ ] **PROB-02**: Research summary covers the quadratic deviation hazard model, inverted-U finding, turning point delta* ~ 0.09
- [ ] **PROB-03**: Key statistics presented accessibly (41 days, 600 positions, 2.65x real vs null A_T, 63% of days with positive deviation)

### Architecture Diagrams

- [ ] **ARCH-01**: Context diagram (mermaid) showing FCI Hook, Vault, CFMM, Protocol Adapters (V3, V4), and Reactive Network
- [ ] **ARCH-02**: Sequence diagram (mermaid) for pool listening flow: listenPool() -> swap/mint/burn events -> metric update -> DeltaPlus derivation
- [ ] **ARCH-03**: Diagrams render correctly in GitHub README markdown

### README Updates

- [ ] **READ-01**: README.md has an Architecture section with both mermaid diagrams embedded
- [ ] **READ-02**: README architecture section is accessible to mixed (technical + non-technical) audience

### Demo

- [ ] **DEMO-01**: Demo script documented — runs NativeV4FeeConcentrationIndex.integration.t.sol with forge command
- [ ] **DEMO-02**: Demo shows FCI tracking through real swap/mint/burn scenarios on V4

### Roadmap Content

- [ ] **ROAD-01**: Roadmap slide lists missing CFMM implementation (linearized power-squared trading function)
- [ ] **ROAD-02**: Roadmap slide lists missing vault/settlement mechanism
- [ ] **ROAD-03**: Roadmap framed as clear next steps, not blockers

### Slide Content

- [ ] **SLID-01**: Problem slide content synthesized from research
- [ ] **SLID-02**: Research summary slide content (approach, key results, demand identification)
- [ ] **SLID-03**: Solution slide content with architecture diagram reference
- [ ] **SLID-04**: Demo slide content with instructions
- [ ] **SLID-05**: Roadmap slide content with missing pieces

## v2 Requirements

### Extended Presentation

- **EPRE-01**: Video recording of demo walkthrough
- **EPRE-02**: Appendix slides with full econometric tables
- **EPRE-03**: Interactive notebook demo (Jupyter) for live audience

## Out of Scope

| Feature | Reason |
|---------|--------|
| New Solidity contracts | Presentation prep only — no contract changes |
| CFMM implementation | Roadmap item to mention, not deliver |
| Vault/settlement implementation | Roadmap item to mention, not deliver |
| Slide tool formatting | We produce markdown content, not Keynote/Slides files |
| Re-running econometrics | Research is complete, we synthesize existing results |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| PROB-01 | Phase ? | Pending |
| PROB-02 | Phase ? | Pending |
| PROB-03 | Phase ? | Pending |
| ARCH-01 | Phase ? | Pending |
| ARCH-02 | Phase ? | Pending |
| ARCH-03 | Phase ? | Pending |
| READ-01 | Phase ? | Pending |
| READ-02 | Phase ? | Pending |
| DEMO-01 | Phase ? | Pending |
| DEMO-02 | Phase ? | Pending |
| ROAD-01 | Phase ? | Pending |
| ROAD-02 | Phase ? | Pending |
| ROAD-03 | Phase ? | Pending |
| SLID-01 | Phase ? | Pending |
| SLID-02 | Phase ? | Pending |
| SLID-03 | Phase ? | Pending |
| SLID-04 | Phase ? | Pending |
| SLID-05 | Phase ? | Pending |

**Coverage:**
- v1 requirements: 18 total
- Mapped to phases: 0
- Unmapped: 18

---
*Requirements defined: 2026-03-18*
*Last updated: 2026-03-18 after initial definition*

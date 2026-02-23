---
name: reverse-engineer
description: business oriented reverse engineering smart contarcts. Use this skill when the user asks to reverse negineer a protocol or, to know how to contarctt or do domething on a code base.
license: Complete terms in LICENSE.txt
---

This skill guides the reverse engineering procedure for smart contract systems (a.k.a. DeFi protocols). It encompasses:
- static analysis with a business-oriented focus

For this skill to be used, it must have the following dependencies:

- slither
- slidther mcp
- surya
- foundry
- github MCP
- evm-mcp-server

> NOTE: Flag the user tools are missing and stop execution if at least one of the tools is missing. If the tool missing is surya, WARN the user but continue

The user provides queries, transaction data, code snippets, or process descriptions of things they would like to achieve. They may include context about the purpose or technical constraints.



## Static Analysis

Before exploring the codebase blindly, we must identify the core contracts and data dependencies the user is looking for based on the prompt input.

You MUST prioritize the use of the Slither MCP server to run your analysis.

If the user flags not understanding something from analysis using this tool, try as a second resource looking using the GitHub MCP server for the org name of the protocol if not given already by the user and look for repositories with

- documentation
- auditing reports
- whitepapers
- research

etc.

We must follow the approach of understanding contracts as state machines. Thus, it is critical to use the framework of state space models.

Use these commands interchangeably with slither equivalents
forge inspect contracts/<REGEX PATTERN>**.sol --storage-layout

forge inspect contracts/<REGEX PATTERN>**.sol --abi

Extract the keywords related to the intent of the user's 

Ask if the query you are about to make makes sense; focus on its semantic meaning, not on the tools to use. For example, instead of saying "I will use Slither MCP to get the metadata of CONTRACT_NAME," frame it in a more goal-oriented way: "To find the state transition flow associated with this process..."

Find the contracts with functions that semantically relate to the user’s intent.

- Abstract the function traces involved in the user’s request.

- Identify state variables that are subject to change and exposed by the user’s intent.

- Read test cases associated with the user state

On the prject directory used save the imporatant results per-user request on docs/static-queries/**.md

Ask on every unrelated iteration to overwirte files or deletem them. An  only do soe per use r conficmation

## Dynamic Analysys

When transactions are given, or prompts imply retrieving state from the blockchain, prioritize using Tenderly services via the MCP server. Ensure that the .env file contains the required variables: ALCHEMY_API_KEY, ETHERSCAN_API_KEY, and TENDERLY_API_KEY, or appropriate bindings for these variables.

interchange the use of this tool with 

cast run <tx_hash> --trace




Save the results for this type of analys on docs/dynamic-queries/**.md
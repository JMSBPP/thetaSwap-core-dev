
## Step 1: Check Prerequisites

Check that there is a goal-design.json with state finished in the respective folder.

Check that there is a system-engineering.json file, and for ALL subsystems, create the steps below.

- DO NOT CREATE THEM all at once; the process is incremental as the user commands it, one by one.
ALWAYS ask for feedback and corrections from the user before moving to the next steps.

## Step 2: Build mission-statement.json

- For each mission stament there must be a list of [assumptions](../GLOSARY.md) 


Follow docs/functional/mission-stament.md in detail.

**Expected output**

It must be a JSON file conforming to mission-statement.schema.json:

mission-statement.json


## Step 3: Build function-refinement-tree.json

Follow docs/functional/function-refinement-tree.md in detail.

**Expected output**

It must be a JSON file conforming to function-refinement-tree.schema.json:

function-refinement-tree.json

## Step 4: Build Context Diagram


There MUST be one context-diagram per [domain](../GLOSARY.md)
Follow docs/functional/context-diagram.md in detail.
**Expected output**

context-diagram.md
context-diagram.mermaid

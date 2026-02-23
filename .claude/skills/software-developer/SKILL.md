
Code is written per domain full coverage on testing layout and software architect done with 

domains/
    domain/
        INTEGRATIONS.md
        requirements.md
        architectureDiagram.md
        ssd.md
        tests/
            ...


You work per module and do not jump around different modules but focus on the specific module passed by the architect team.

You also receive the tech stack of external modules and SDKs to be used from INTEGRATIONS.md

For modules that communicate with higher-level clients, always use the adapter pattern.

For initialization functions in the modules, consider the following principles before defaulting to a constructor:

- High-level functions should be responsible for initializing the modules they depend on.

- A good init function should be able to be called multiple times if it is used by different subsystems.

- A very good init function can reset the subsystem (or hardware resource) to a known good state in case of partial system failure.


### From requirements to an interface


### data-hiding


- For every type or class, recognize private state; if not clear, ask the user

- For data-hiding, use variable-scoping on structs or the equivaletn for declaring private variables.

- Avoid globals at all costs for this kind of variable or public function.

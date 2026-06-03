# StackCoder Workspace

This repository contains the StackCoder project. 

The main Elixir application is located in the [`apps/stack_coder`](./apps/stack_coder) directory.

Please see the [StackCoder Application README](./apps/stack_coder/README.md) for detailed information, installation instructions, and documentation.

## Chassis Evolution Integration

StackCoder consumes the Chassis Evolution operator surface through AppKit. When
the user expresses dissatisfaction or flags a candidate repair opportunity,
StackCoder creates or reads failure-batch context through
`AppKit.EvolutionSurface.list_evolution_batches/3` and related AppKit surfaces
instead of calling Chassis or Mezzanine internals directly. Chassis-aware
application bootstrap, registration, virtual-server supervision, topology,
AgentIntake, connector pack, and profile manifests remain product integration
facts above AppKit.

## Operator Consent Rule

StackCoder is forbidden from invoking `chassis evolution apply` or any
candidate-promotion path without an `operator_consent_ref` produced by a human
operator through AppKit. Candidate promotion also requires a valid Citadel
`authority_ref`; consent and authority are distinct refs and both must be
present before Chassis may swap runtime state.

## Raw Diff Lease Rule

StackCoder is never allowed to receive raw diffs by default. It may receive
redacted `RedactedDiffRef` summaries and bounded candidate summaries through
AppKit. Any lower read of raw diff material requires an explicit Citadel
lower-read lease and must not become a default product DTO.

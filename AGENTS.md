# StackCoder Agent Instructions

StackCoder owns the provider-free local Profile B host over AppKit. Do not put
Extravaganza product behavior or lower runtime ownership here.

## Boundaries

- Own StackCoder-local daemon, CLI, receipt, presenter, and Profile B proof
  surfaces.
- Product orchestration belongs in Extravaganza. Runtime/control-plane behavior
  belongs in AppKit, Mezzanine, Citadel, Jido Integration, or Execution Plane.
- StackCoder is not in the Weld consumer set. Do not add a Weld dependency,
  Weld task, or Weld Credo check as part of Phase 2 cleanup.

## Dependency Sources

- Cross-repo dependency selection belongs in
  `build_support/dependency_sources.config.exs` and is consumed through the
  canonical `build_support/dependency_sources.exs` helper.
- The app package keeps its own self-contained
  `apps/stack_coder/build_support/dependency_sources.*` files for package-mode
  dependency selection.
- Machine-local dependency overrides belong in `.dependency_sources.local.exs`
  or `apps/stack_coder/.dependency_sources.local.exs`. Keep those files
  untracked.
- Dependency source selection must not read environment variables.

## Runtime Environment

- Runtime application code under `apps/stack_coder/lib/**` must not call direct
  OS environment APIs such as `System.get_env/1`, `System.fetch_env/1`,
  `System.fetch_env!/1`, `System.put_env/2`, `System.delete_env/1`, or
  `System.get_env/0`.
- Deployment environment reads belong at OTP boot boundaries such as
  `config/runtime.exs` or a `Config.Provider`. Runtime modules should receive
  explicit options or materialized application config.

## Verification

- Run `mix ci` from the repository root before committing.

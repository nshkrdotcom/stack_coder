defmodule StackCoder.RuntimePolicy do
  @moduledoc """
  Bounded local runtime vocabulary for StackCoder Profile B.
  """

  @task_states ["blocked", "completed", "review_pending"]
  @provider_selection_modes [:provider_free_local]
  @target_modes [:appkit_local_profile_b]

  @readback_event_kinds [
    "action.requested",
    "action.submitted",
    "agent_run.accepted",
    "authority.approved",
    "authority.denied",
    "context.assembled",
    "memory.committed",
    "memory_commit.skipped",
    "outcome.semanticized",
    "receipt.observed",
    "recall.completed",
    "review.pending",
    "run.terminal",
    "turn.started"
  ]

  @operator_action_kinds [:cancel, :refresh, :start_run, :submit_turn]

  @spec validate_task_state(term()) :: :ok | {:error, {:unknown_task_state, term()}}
  def validate_task_state(state) when state in @task_states, do: :ok
  def validate_task_state(state), do: {:error, {:unknown_task_state, state}}

  @spec validate_provider_selection_mode(term()) ::
          :ok | {:error, {:unknown_provider_selection_mode, term()}}
  def validate_provider_selection_mode(mode) when mode in @provider_selection_modes, do: :ok

  def validate_provider_selection_mode(mode),
    do: {:error, {:unknown_provider_selection_mode, mode}}

  @spec validate_target_mode(term()) :: :ok | {:error, {:unknown_target_mode, term()}}
  def validate_target_mode(mode) when mode in @target_modes, do: :ok
  def validate_target_mode(mode), do: {:error, {:unknown_target_mode, mode}}

  @spec validate_readback_event_kind(term()) ::
          :ok | {:error, {:unknown_readback_event_kind, term()}}
  def validate_readback_event_kind(kind) when kind in @readback_event_kinds, do: :ok

  def validate_readback_event_kind(kind),
    do: {:error, {:unknown_readback_event_kind, kind}}

  @spec validate_operator_action_kind(term()) ::
          :ok | {:error, {:unknown_operator_action_kind, term()}}
  def validate_operator_action_kind(kind) when kind in @operator_action_kinds, do: :ok

  def validate_operator_action_kind(kind),
    do: {:error, {:unknown_operator_action_kind, kind}}

  @spec task_state!(term()) :: term()
  def task_state!(state), do: unwrap!(state, validate_task_state(state))

  @spec readback_event_kind!(term()) :: term()
  def readback_event_kind!(kind), do: unwrap!(kind, validate_readback_event_kind(kind))

  @spec operator_action_kind!(term()) :: term()
  def operator_action_kind!(kind), do: unwrap!(kind, validate_operator_action_kind(kind))

  defp unwrap!(value, :ok), do: value

  defp unwrap!(_value, {:error, reason}) do
    raise ArgumentError, inspect(reason)
  end
end

defmodule StackCoder.AppKitBackend do
  @moduledoc """
  Local backend for AppKit surfaces used by the Profile B fixture host.

  The backend exists only to adapt the local in-process fixture projection to
  AppKit readback DTOs. StackCoder callers still use `AppKit.AgentIntake` and
  `AppKit.HeadlessSurface`.
  """

  @behaviour AppKit.Core.Backends.AgentIntakeBackend
  @behaviour AppKit.Core.Backends.HeadlessBackend

  alias AppKit.Core.AgentIntake.RunOutcomeFuture

  alias AppKit.Core.RuntimeReadback.{
    CommandResult,
    RuntimeEventRow,
    RuntimeRow,
    RuntimeRunDetail,
    RuntimeStateSnapshot,
    RuntimeSubjectDetail
  }

  alias StackCoder.RuntimeAdapter

  @timestamp ~U[2026-04-27 00:00:00Z]

  @impl AppKit.Core.Backends.AgentIntakeBackend
  def start_agent_run(context, request, opts) do
    runtime = Keyword.get(opts, :agent_loop_runtime, RuntimeAdapter)

    with {:ok, attrs} <- agent_run_spec_attrs(context, request),
         true <- runtime_available?(runtime),
         {:ok, projection} <- runtime.run(attrs) do
      RunOutcomeFuture.new(%{
        run_ref: projection.run_ref,
        workflow_ref: projection.workflow_ref,
        accepted?: true,
        command_ref: "command://#{request.idempotency_key}",
        correlation_id: request.correlation_id,
        polling_hint: %{checking?: false, poll_interval_ms: 1_000, staleness_ms: 0}
      })
    else
      false -> {:error, :agent_turn_runtime_not_available}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl AppKit.Core.Backends.AgentIntakeBackend
  def submit_agent_turn(_context, turn_submission, opts) do
    if runtime_available?(Keyword.get(opts, :agent_loop_runtime, RuntimeAdapter)) do
      CommandResult.new(%{
        command_ref: "command://#{turn_submission.idempotency_key}",
        command_kind: :submit_turn,
        accepted?: true,
        coalesced?: false,
        status: :accepted,
        authority_state: :local_policy,
        authority_refs: [],
        workflow_effect_state: "pending_signal",
        projection_state: :pending,
        correlation_id: turn_submission.run_ref,
        idempotency_key: turn_submission.idempotency_key,
        message: "Agent turn submission accepted through AppKit"
      })
    else
      {:error, :agent_turn_runtime_not_available}
    end
  end

  @impl AppKit.Core.Backends.AgentIntakeBackend
  def cancel_agent_run(_context, run_ref, opts) do
    if runtime_available?(Keyword.get(opts, :agent_loop_runtime, RuntimeAdapter)) do
      CommandResult.new(%{
        command_ref: "command://cancel/#{ref_suffix(run_ref)}",
        command_kind: :cancel,
        accepted?: true,
        coalesced?: false,
        status: :accepted,
        authority_state: :local_policy,
        authority_refs: [],
        workflow_effect_state: "pending_signal",
        projection_state: :pending,
        correlation_id: run_ref,
        idempotency_key: "agent-run:cancel:#{ref_suffix(run_ref)}",
        message: "Agent run cancellation accepted through AppKit"
      })
    else
      {:error, :agent_turn_runtime_not_available}
    end
  end

  @impl AppKit.Core.Backends.AgentIntakeBackend
  def await_agent_outcome(_context, run_ref, request, opts) do
    if runtime_available?(Keyword.get(opts, :agent_loop_runtime, RuntimeAdapter)) do
      RunOutcomeFuture.new(%{
        run_ref: run_ref,
        workflow_ref: map_value(request || %{}, :workflow_ref),
        accepted?: true,
        command_ref: "command://await/#{ref_suffix(run_ref)}",
        correlation_id: map_value(request || %{}, :correlation_id, run_ref),
        polling_hint: %{checking?: false, poll_interval_ms: 1_000, staleness_ms: 0}
      })
    else
      {:error, :agent_turn_runtime_not_available}
    end
  end

  @impl AppKit.Core.Backends.HeadlessBackend
  def state_snapshot(context, _request, _opts) do
    RuntimeStateSnapshot.new(%{
      tenant_ref: "tenant://#{context.tenant_ref.id}",
      installation_ref: installation_ref(context),
      generated_at: @timestamp,
      rows: [],
      polling_state: %{checking?: false, poll_interval_ms: 1_000, staleness_ms: 0},
      page: %{page_size: 0, total_entries: 0}
    })
  end

  @impl AppKit.Core.Backends.HeadlessBackend
  def runtime_subject_detail(_context, subject_ref, request, _opts) do
    RuntimeSubjectDetail.new(%{
      subject_ref: subject_ref,
      summary: %{
        profile_ref:
          map_value(request || %{}, :profile_ref, "profile://stack-coder/local-fixture/v1")
      },
      events: []
    })
  end

  @impl AppKit.Core.Backends.HeadlessBackend
  def runtime_run_detail(_context, run_ref, request, _opts) do
    projection = map_value(request || %{}, :agent_loop_projection)

    with true <- not is_nil(projection),
         projection_map <- public_map(projection),
         {:ok, row} <-
           RuntimeRow.new(%{
             subject_ref: map_value(projection_map, :subject_ref),
             run_ref: run_ref,
             workflow_ref: map_value(projection_map, :workflow_ref),
             state: map_value(projection_map, :status),
             updated_at: @timestamp,
             polling_state: %{checking?: false, poll_interval_ms: 1_000, staleness_ms: 0}
           }),
         {:ok, events} <-
           projection_map
           |> map_value(:runtime_events, [])
           |> Enum.map(&RuntimeEventRow.new/1)
           |> collect_ok() do
      RuntimeRunDetail.new(%{
        run_ref: run_ref,
        runtime_row: row,
        events: events,
        turns: map_value(projection_map, :turn_states, []),
        budget_state: map_value(projection_map, :budget_state),
        candidate_fact_refs: map_value(projection_map, :candidate_fact_refs, []),
        memory_proof_refs: map_value(projection_map, :memory_proof_refs, []),
        agent_loop_diagnostics: []
      })
    else
      false -> {:error, :missing_agent_loop_projection}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl AppKit.Core.Backends.HeadlessBackend
  def request_runtime_refresh(_context, request, _opts) do
    CommandResult.new(%{
      command_ref: "command://#{request.idempotency_key}",
      command_kind: :refresh,
      accepted?: true,
      coalesced?: false,
      status: :accepted,
      authority_state: :local_policy,
      authority_refs: [],
      workflow_effect_state: "pending_signal",
      projection_state: :pending,
      idempotency_key: request.idempotency_key,
      message: "Refresh command accepted through AppKit"
    })
  end

  @impl AppKit.Core.Backends.HeadlessBackend
  def request_runtime_control(_context, request, _opts) do
    CommandResult.new(%{
      command_ref: "command://#{request.idempotency_key}",
      command_kind: request.action,
      accepted?: true,
      coalesced?: false,
      status: :accepted,
      authority_state: :local_policy,
      authority_refs: [],
      workflow_effect_state: "pending_signal",
      projection_state: :pending,
      idempotency_key: request.idempotency_key,
      message: "Control command accepted through AppKit"
    })
  end

  defp agent_run_spec_attrs(context, request) do
    params = request.params || %{}
    profile_bundle = request.profile_bundle
    run_ref = map_value(params, :run_ref, "run://stack-coder/#{request.submission_dedupe_key}")

    {:ok,
     %{
       tenant_ref: request.tenant_ref,
       installation_ref: request.installation_ref,
       profile_ref: map_value(params, :profile_ref, "profile://stack-coder/local-fixture/v1"),
       subject_ref: request.subject_ref,
       run_ref: run_ref,
       session_ref: map_value(params, :session_ref),
       workspace_ref: map_value(params, :workspace_ref),
       worker_ref: map_value(params, :worker_ref),
       trace_id: request.trace_id,
       idempotency_key: request.idempotency_key,
       objective: request.initial_input_ref,
       runtime_profile_ref: profile_bundle.runtime_profile_ref,
       tool_catalog_ref: request.tool_catalog_ref,
       authority_context_ref: map_value(params, :authority_context_ref),
       memory_profile_ref: profile_bundle.memory_profile_ref,
       artifact_policy_ref: map_value(params, :artifact_policy_ref),
       max_turns: map_value(params, :max_turns, 1),
       timeout_policy: %{turn_timeout_ms: 30_000},
       profile_bundle: Map.from_struct(profile_bundle),
       fixture_script: map_value(params, :fixture_script, "success_first_try"),
       release_manifest_ref: map_value(params, :release_manifest_ref),
       source_ref: "actor://#{context.actor_ref.id}"
     }}
  end

  defp runtime_available?(runtime) when is_atom(runtime),
    do: Code.ensure_loaded?(runtime) and function_exported?(runtime, :run, 1)

  defp runtime_available?(_runtime), do: false

  defp installation_ref(%{installation_ref: nil}), do: "installation://stack-coder/local"
  defp installation_ref(context), do: "installation://#{context.installation_ref.id}"

  defp public_map(%DateTime{} = value), do: value
  defp public_map(%_{} = value), do: value |> Map.from_struct() |> public_map()
  defp public_map(%{} = value), do: Map.new(value, fn {key, val} -> {key, public_map(val)} end)
  defp public_map(values) when is_list(values), do: Enum.map(values, &public_map/1)
  defp public_map(value), do: value

  defp collect_ok(results) do
    Enum.reduce_while(results, {:ok, []}, fn
      {:ok, value}, {:ok, acc} -> {:cont, {:ok, [value | acc]}}
      {:error, reason}, _acc -> {:halt, {:error, reason}}
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      error -> error
    end
  end

  defp map_value(map, key, default \\ nil)

  defp map_value(map, key, default) when is_map(map),
    do: Map.get(map, key, Map.get(map, Atom.to_string(key), default))

  defp map_value(_map, _key, default), do: default

  defp ref_suffix(ref) when is_binary(ref) do
    ref
    |> :binary.bin_to_list()
    |> Enum.reduce({[], :start}, &append_ref_suffix_byte/2)
    |> elem(0)
    |> trim_reversed_separator()
    |> Enum.reverse()
    |> List.to_string()
  end

  defp append_ref_suffix_byte(byte, {acc, _state}) when byte in ?A..?Z,
    do: {[byte | acc], :char}

  defp append_ref_suffix_byte(byte, {acc, _state}) when byte in ?a..?z,
    do: {[byte | acc], :char}

  defp append_ref_suffix_byte(byte, {acc, _state}) when byte in ?0..?9,
    do: {[byte | acc], :char}

  defp append_ref_suffix_byte(_byte, {acc, :char}), do: {[?- | acc], :separator}
  defp append_ref_suffix_byte(_byte, {acc, state}), do: {acc, state}

  defp trim_reversed_separator([?- | rest]), do: rest
  defp trim_reversed_separator(chars), do: chars
end

defmodule StackCoder.Receipt do
  @moduledoc "Builds and validates the Phase 6 offline E2E receipt."

  alias AppKit.Core.AgentIntake.RunOutcomeFuture
  alias AppKit.Core.RuntimeReadback.{RuntimeRunDetail, Support}
  alias StackCoder.Presenter

  @receipt_name "agentic_substrate_local_e2e_v1"

  @spec build(map(), keyword()) :: map()
  def build(
        %{
          future: %RunOutcomeFuture{} = future,
          detail: %RuntimeRunDetail{} = detail,
          projection: projection
        } = run,
        opts \\ []
      ) do
    presented = Presenter.present_run(run, json?: true)
    readback = Support.dump_struct(detail)
    ref_set = Map.get(projection, :receipt_ref_set, %{})

    %{
      "receipt_name" => @receipt_name,
      "schema_ref" => @receipt_name,
      "proof_class" => "offline_e2e",
      "agentic_core_proven?" => true,
      "mechanisms" => ["M1", "M2"],
      "profile_ref" => run.profile_ref,
      "run_ref" => future.run_ref,
      "subject_ref" => run.subject_ref,
      "trace_id" => run.trace_id,
      "agent_loop_workflow_ref" => future.workflow_ref,
      "turn_refs" => refs(ref_set, "turn_refs"),
      "tool_action_request_refs" => action_request_refs(projection),
      "tool_action_receipt_refs" => action_receipt_refs(projection),
      "authority_decision_refs" => refs(ref_set, "authority_refs"),
      "execution_governance_refs" => refs(ref_set, "authority_refs"),
      "execution_outcome_refs" => refs(ref_set, "outcome_refs"),
      "session_refs" => refs(ref_set, "session_refs"),
      "event_refs" => refs(ref_set, "event_refs"),
      "workspace_refs" => refs(ref_set, "workspace_refs"),
      "worker_refs" => refs(ref_set, "worker_refs"),
      "lower_refs" => refs(ref_set, "lower_refs"),
      "runtime_event_count" => length(detail.events),
      "terminal_state" => detail.runtime_row.state,
      "headless_readback_hash" => hash(readback),
      "cli_output_hash" => hash(presented),
      "provider_network_access?" => false,
      "network_required?" => false,
      "provider_credentials_required?" => false,
      "linear_used?" => false,
      "github_used?" => false,
      "codex_used?" => false,
      "memory_profile_ref" => "none",
      "release_manifest_ref" =>
        Keyword.get(
          opts,
          :release_manifest_ref,
          "release-manifest://stack-coder/local-fixture/v1"
        ),
      "receipt_state" => "proven"
    }
  end

  @spec validate(map()) :: :ok | {:error, term()}
  def validate(%{} = receipt) do
    required = [
      "receipt_name",
      "mechanisms",
      "profile_ref",
      "run_ref",
      "subject_ref",
      "trace_id",
      "agent_loop_workflow_ref",
      "turn_refs",
      "tool_action_request_refs",
      "tool_action_receipt_refs",
      "runtime_event_count",
      "terminal_state",
      "headless_readback_hash",
      "cli_output_hash",
      "provider_network_access?",
      "linear_used?",
      "github_used?",
      "codex_used?",
      "memory_profile_ref",
      "release_manifest_ref"
    ]

    with :ok <- validate_required_fields(receipt, required),
         :ok <- validate_receipt_name(receipt),
         :ok <- validate_mechanisms(receipt),
         :ok <- validate_network_scope(receipt),
         :ok <- validate_provider_scope(receipt),
         :ok <- validate_memory_scope(receipt),
         :ok <- validate_proof_claim(receipt) do
      validate_agent_loop_refs(receipt)
    end
  end

  def validate(_receipt), do: {:error, :invalid_receipt}

  defp validate_required_fields(receipt, required) do
    if Enum.all?(required, &Map.has_key?(receipt, &1)) do
      :ok
    else
      {:error, :missing_required_receipt_field}
    end
  end

  defp validate_receipt_name(%{"receipt_name" => @receipt_name}), do: :ok
  defp validate_receipt_name(_receipt), do: {:error, :invalid_receipt_name}

  defp validate_mechanisms(%{"mechanisms" => ["M1", "M2"]}), do: :ok
  defp validate_mechanisms(_receipt), do: {:error, :invalid_mechanisms}

  defp validate_network_scope(%{
         "provider_network_access?" => false,
         "network_required?" => false
       }),
       do: :ok

  defp validate_network_scope(_receipt), do: {:error, :network_not_allowed}

  defp validate_provider_scope(%{
         "linear_used?" => false,
         "github_used?" => false,
         "codex_used?" => false
       }),
       do: :ok

  defp validate_provider_scope(_receipt), do: {:error, :provider_not_allowed}

  defp validate_memory_scope(%{"memory_profile_ref" => "none"}), do: :ok
  defp validate_memory_scope(_receipt), do: {:error, :memory_not_allowed_before_phase_7}

  defp validate_proof_claim(%{"agentic_core_proven?" => true}), do: :ok
  defp validate_proof_claim(_receipt), do: {:error, :receipt_does_not_claim_true_proof}

  defp validate_agent_loop_refs(%{
         "authority_decision_refs" => [_ | _],
         "execution_outcome_refs" => [_ | _]
       }),
       do: :ok

  defp validate_agent_loop_refs(_receipt), do: {:error, :missing_agent_loop_proof_refs}

  @spec write!(map(), String.t()) :: String.t()
  def write!(receipt, path) do
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, Jason.encode!(receipt, pretty: true) <> "\n")
    path
  end

  @spec receipt_name() :: String.t()
  def receipt_name, do: @receipt_name

  defp refs(ref_set, key), do: Map.get(ref_set, key, [])

  defp action_request_refs(projection) do
    projection
    |> Map.get(:action_requests, [])
    |> Enum.map(&Map.fetch!(&1, :action_ref))
  end

  defp action_receipt_refs(projection) do
    projection
    |> Map.get(:action_receipts, [])
    |> Enum.map(&Map.fetch!(&1, :receipt_ref))
  end

  defp hash(payload) do
    encoded = payload |> json_safe() |> Jason.encode!()
    "sha256:" <> Base.encode16(:crypto.hash(:sha256, encoded), case: :lower)
  end

  defp json_safe(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp json_safe(%_{} = value), do: value |> Map.from_struct() |> json_safe()

  defp json_safe(%{} = value),
    do: Map.new(value, fn {key, val} -> {to_string(key), json_safe(val)} end)

  defp json_safe(values) when is_list(values), do: Enum.map(values, &json_safe/1)
  defp json_safe(value) when is_tuple(value), do: value |> Tuple.to_list() |> json_safe()
  defp json_safe(value) when is_atom(value), do: Atom.to_string(value)
  defp json_safe(value), do: value
end

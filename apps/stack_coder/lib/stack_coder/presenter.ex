defmodule StackCoder.Presenter do
  @moduledoc "Plain-text and JSON presentation for local readback."

  alias AppKit.Core.AgentIntake.RunOutcomeFuture
  alias AppKit.Core.RuntimeReadback.{CommandResult, RuntimeEventRow, RuntimeRunDetail}

  @spec present_run(map(), keyword()) :: map()
  def present_run(
        %{future: %RunOutcomeFuture{} = future, detail: %RuntimeRunDetail{} = detail} = run,
        opts \\ []
      ) do
    %{
      "schema_ref" => "stack_coder/local_run.v1",
      "profile_ref" => run.profile_ref,
      "run_ref" => future.run_ref,
      "workflow_ref" => future.workflow_ref,
      "subject_ref" => run.subject_ref,
      "terminal_state" => detail.runtime_row.state,
      "event_count" => length(detail.events),
      "events" => Enum.map(detail.events, &present_event/1),
      "turns" => detail.turns,
      "budget_state" => detail.budget_state,
      "candidate_fact_refs" => detail.candidate_fact_refs,
      "memory_proof_refs" => detail.memory_proof_refs,
      "receipt_ref" => receipt_name(run),
      "output_mode" => if(Keyword.get(opts, :json?, false), do: "json", else: "text")
    }
  end

  @spec present_detail(RuntimeRunDetail.t()) :: map()
  def present_detail(%RuntimeRunDetail{} = detail) do
    %{
      "schema_ref" => detail.schema_ref,
      "run_ref" => detail.run_ref,
      "state" => detail.runtime_row.state,
      "workflow_ref" => detail.runtime_row.workflow_ref,
      "events" => Enum.map(detail.events, &present_event/1),
      "turns" => detail.turns,
      "budget_state" => detail.budget_state,
      "candidate_fact_refs" => detail.candidate_fact_refs,
      "memory_proof_refs" => detail.memory_proof_refs
    }
  end

  @spec present_events([RuntimeEventRow.t()]) :: [map()]
  def present_events(events), do: Enum.map(events, &present_event/1)

  @spec present_command(CommandResult.t()) :: map()
  def present_command(%CommandResult{} = command) do
    %{
      "schema_ref" => "runtime_readback/command_result.v1",
      "command_ref" => command.command_ref,
      "command_kind" => to_string(command.command_kind),
      "accepted?" => command.accepted?,
      "status" => to_string(command.status),
      "workflow_effect_state" => command.workflow_effect_state,
      "projection_state" => to_string(command.projection_state)
    }
  end

  @spec render(map() | [map()], keyword()) :: String.t()
  def render(payload, opts \\ [])

  def render(payload, opts) when is_map(payload) do
    if Keyword.get(opts, :json?, false) do
      Jason.encode!(payload, pretty: true)
    else
      render_text(payload)
    end
  end

  def render(payload, opts) when is_list(payload) do
    if Keyword.get(opts, :json?, false) do
      Jason.encode!(payload, pretty: true)
    else
      payload
      |> Enum.map(&render_text/1)
      |> Enum.join("\n")
    end
  end

  defp present_event(%RuntimeEventRow{} = event) do
    %{
      "event_ref" => event.event_ref,
      "event_seq" => event.event_seq,
      "event_kind" => event.event_kind,
      "message_summary" => event.message_summary,
      "run_ref" => event.run_ref,
      "turn_ref" => event.turn_ref
    }
  end

  defp receipt_name(%{receipt: %{} = receipt}), do: Map.get(receipt, "receipt_name")
  defp receipt_name(_run), do: nil

  defp render_text(%{"schema_ref" => "stack_coder/local_run.v1"} = payload) do
    [
      "run_ref: #{payload["run_ref"]}",
      "workflow_ref: #{payload["workflow_ref"]}",
      "terminal_state: #{payload["terminal_state"]}",
      "event_count: #{payload["event_count"]}"
    ]
    |> Enum.join("\n")
  end

  defp render_text(%{"event_kind" => event_kind} = payload) do
    "#{payload["event_seq"]}: #{event_kind} #{payload["message_summary"]}"
  end

  defp render_text(%{"command_ref" => command_ref} = payload) do
    "#{payload["command_kind"]}: #{payload["status"]} #{command_ref}"
  end

  defp render_text(payload), do: Jason.encode!(payload)
end

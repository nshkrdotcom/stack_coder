defmodule StackCoder.RuntimeAdapter do
  @moduledoc """
  Local fixture adapter configured behind the AppKit bridge.

  StackCoder uses this module as an AppKit bridge option. Product-facing code
  still starts and reads runs through AppKit surfaces.
  """

  alias Mezzanine.WorkflowRuntime.AgentLoop

  @table __MODULE__.Table

  @spec run(map()) :: {:ok, struct()} | {:error, term()}
  def run(attrs) when is_map(attrs) do
    ensure_table!()
    agent_loop = agent_loop_module()

    with {:ok, projection} <- agent_loop.run(attrs) do
      :ets.insert(@table, {projection.run_ref, projection})
      {:ok, projection}
    end
  end

  @spec projection(String.t()) :: {:ok, struct()} | {:error, :not_found}
  def projection(run_ref) do
    ensure_table!()

    case :ets.lookup(@table, run_ref) do
      [{^run_ref, projection}] -> {:ok, projection}
      [] -> {:error, :not_found}
    end
  end

  @spec reset!() :: :ok
  def reset! do
    ensure_table!()
    :ets.delete_all_objects(@table)
    :ok
  end

  defp ensure_table! do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [:named_table, :public, {:read_concurrency, true}])
        :ok

      _tid ->
        :ok
    end
  end

  defp agent_loop_module do
    AgentLoop
  end
end

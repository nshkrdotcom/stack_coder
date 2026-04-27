defmodule Mix.Tasks.StackCoder.Run do
  @shortdoc "Run or inspect the StackCoder local fixture host"

  @moduledoc """
  Starts and reads Profile B through AppKit.

      mix stack_coder.run --task '{"objective":"explain current repo layout"}'
      mix stack_coder.run --watch RUN_REF
      mix stack_coder.run --resume RUN_REF
      mix stack_coder.run --cancel RUN_REF
  """

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    case StackCoder.CLI.main(args) do
      :ok -> :ok
      {:error, reason} -> Mix.raise("stack_coder.run failed: #{inspect(reason)}")
    end
  end
end

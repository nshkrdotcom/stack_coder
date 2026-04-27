defmodule StackCoder.CLI do
  @moduledoc "Command-line entrypoint for StackCoder local runs."

  alias StackCoder.{LocalHost, Presenter}

  @spec main([String.t()]) :: :ok | {:error, term()}
  def main(args) do
    case parse(args) do
      {:run, task, opts} -> print_result(LocalHost.run(task, opts), :presentation, opts)
      {:detail, run_ref, opts} -> print_result(LocalHost.detail(run_ref, opts), nil, opts)
      {:events, run_ref, opts} -> print_result(LocalHost.events(run_ref, opts), nil, opts)
      {:cancel, run_ref, opts} -> print_result(LocalHost.cancel(run_ref, opts), nil, opts)
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse(args) do
    {opts, positional, invalid} =
      OptionParser.parse(args,
        strict: [
          task: :string,
          watch: :boolean,
          resume: :string,
          cancel: :string,
          detail: :string,
          events: :string,
          json: :boolean,
          idempotency_key: :string,
          receipt_path: :string
        ]
      )

    cond do
      invalid != [] ->
        {:error, {:invalid_options, invalid}}

      run_ref = Keyword.get(opts, :cancel) ->
        {:cancel, run_ref, cli_opts(opts)}

      run_ref = Keyword.get(opts, :resume) ->
        {:detail, run_ref, cli_opts(opts)}

      run_ref = Keyword.get(opts, :detail) ->
        {:detail, run_ref, cli_opts(opts)}

      run_ref = Keyword.get(opts, :events) ->
        {:events, run_ref, cli_opts(opts)}

      Keyword.get(opts, :watch, false) ->
        {:events, positional_ref(positional), cli_opts(opts)}

      Keyword.has_key?(opts, :task) ->
        {:run, Keyword.fetch!(opts, :task), cli_opts(opts)}

      positional == ["run"] and Keyword.has_key?(opts, :task) ->
        {:run, Keyword.fetch!(opts, :task), cli_opts(opts)}

      match?(["status", _], positional) or match?(["detail", _], positional) ->
        [_cmd, run_ref] = positional
        {:detail, run_ref, cli_opts(opts)}

      match?(["events", _], positional) ->
        [_cmd, run_ref] = positional
        {:events, run_ref, cli_opts(opts)}

      match?(["cancel", _], positional) ->
        [_cmd, run_ref] = positional
        {:cancel, run_ref, cli_opts(opts)}

      true ->
        {:error, :missing_command}
    end
  end

  defp positional_ref([_cmd, run_ref]), do: run_ref
  defp positional_ref([run_ref]), do: run_ref
  defp positional_ref(_positional), do: "run://stack-coder/stack-coder-local-fixture"

  defp cli_opts(opts) do
    opts
    |> Keyword.take([:idempotency_key, :receipt_path])
    |> Keyword.put(:json?, Keyword.get(opts, :json, false))
  end

  defp print_result({:ok, payload}, key, opts) do
    payload = if key, do: Map.fetch!(payload, key), else: payload
    Mix.shell().info(Presenter.render(payload, opts))
    :ok
  end

  defp print_result({:error, reason}, _key, _opts), do: {:error, reason}
end

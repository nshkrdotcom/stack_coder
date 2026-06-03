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

    case invalid do
      [] -> parse_valid(opts, positional)
      _ -> {:error, {:invalid_options, invalid}}
    end
  end

  defp parse_valid(opts, positional) do
    option_command(opts, positional) ||
      positional_command(opts, positional) ||
      {:error, :missing_command}
  end

  defp option_command(opts, positional) do
    cond do
      run_ref = Keyword.get(opts, :cancel) -> {:cancel, run_ref, cli_opts(opts)}
      run_ref = Keyword.get(opts, :resume) -> {:detail, run_ref, cli_opts(opts)}
      run_ref = Keyword.get(opts, :detail) -> {:detail, run_ref, cli_opts(opts)}
      run_ref = Keyword.get(opts, :events) -> {:events, run_ref, cli_opts(opts)}
      Keyword.get(opts, :watch, false) -> {:events, positional_ref(positional), cli_opts(opts)}
      Keyword.has_key?(opts, :task) -> {:run, Keyword.fetch!(opts, :task), cli_opts(opts)}
      true -> nil
    end
  end

  defp positional_command(opts, ["run"]) do
    if Keyword.has_key?(opts, :task), do: {:run, Keyword.fetch!(opts, :task), cli_opts(opts)}
  end

  defp positional_command(opts, ["run", prompt]) when is_binary(prompt),
    do: {:run, prompt, cli_opts(opts)}

  defp positional_command(opts, ["review-pr", pr_ref]) when is_binary(pr_ref),
    do: {:run, "review pull request " <> pr_ref, cli_opts(opts)}

  defp positional_command(opts, ["context.index", repo_path]) when is_binary(repo_path),
    do:
      {:run, %{"input_ref" => "input://stack-coder/context-index/" <> hash(repo_path)},
       cli_opts(opts)}

  defp positional_command(opts, ["turn.history" | _rest]),
    do: {:events, "run://stack-coder/stack-coder-local-fixture", cli_opts(opts)}

  defp positional_command(opts, [cmd, run_ref]) when cmd in ["status", "detail"],
    do: {:detail, run_ref, cli_opts(opts)}

  defp positional_command(opts, ["events", run_ref]), do: {:events, run_ref, cli_opts(opts)}
  defp positional_command(opts, ["cancel", run_ref]), do: {:cancel, run_ref, cli_opts(opts)}
  defp positional_command(_opts, _positional), do: nil

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

  defp hash(value) do
    :crypto.hash(:sha256, value)
    |> Base.encode16(case: :lower)
    |> binary_part(0, 24)
  end
end

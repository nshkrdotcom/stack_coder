defmodule StackCoder.LocalHost do
  @moduledoc "Local CLI host that composes StackCoder Profile B through AppKit."

  alias AppKit.Core.AgentIntake.AgentRunRequest
  alias AppKit.HeadlessSurface
  alias StackCoder.{AppKitContext, Config, LocalPack, LocalProfile, Presenter, Receipt}

  @backend StackCoder.AppKitBackend
  @runtime StackCoder.RuntimeAdapter

  @spec run(String.t() | map(), keyword()) :: {:ok, map()} | {:error, term()}
  def run(task, opts \\ []) do
    config = Config.defaults(opts)

    with {:ok, context} <- AppKitContext.new(opts),
         {:ok, request} <- agent_run_request(task, config),
         {:ok, future} <- AppKit.AgentIntake.start_agent_run(context, request, appkit_opts(opts)),
         {:ok, projection} <- @runtime.projection(future.run_ref),
         {:ok, detail} <- read_detail(context, future.run_ref, projection, config),
         run <- %{
           future: future,
           detail: detail,
           projection: projection,
           profile_ref: LocalPack.profile_ref(),
           subject_ref: config.subject_ref,
           trace_id: config.trace_id
         },
         receipt <- Receipt.build(run, release_manifest_ref: config.release_manifest_ref),
         :ok <- Receipt.validate(receipt),
         artifact_paths <- write_artifacts!(run, receipt, config, opts) do
      run = Map.put(run, :receipt, receipt)

      {:ok,
       run
       |> Map.put(:artifact_paths, artifact_paths)
       |> Map.put(:presentation, Presenter.present_run(run, opts))}
    end
  end

  @spec detail(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def detail(run_ref, opts \\ []) do
    config = Config.defaults(opts)

    with {:ok, context} <- AppKitContext.new(opts),
         {:ok, projection} <- @runtime.projection(run_ref),
         {:ok, detail} <- read_detail(context, run_ref, projection, config) do
      {:ok, Presenter.present_detail(detail)}
    end
  end

  @spec events(String.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def events(run_ref, opts \\ []) do
    config = Config.defaults(opts)

    with {:ok, context} <- AppKitContext.new(opts),
         {:ok, projection} <- @runtime.projection(run_ref),
         {:ok, detail} <- read_detail(context, run_ref, projection, config) do
      {:ok, Presenter.present_events(detail.events)}
    end
  end

  @spec cancel(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def cancel(run_ref, opts \\ []) do
    with {:ok, context} <- AppKitContext.new(opts),
         {:ok, command} <-
           AppKit.AgentIntake.cancel_agent_run(context, run_ref, appkit_opts(opts)) do
      {:ok, Presenter.present_command(command)}
    end
  end

  @spec request_for_task(String.t() | map(), keyword()) ::
          {:ok, AgentRunRequest.t()} | {:error, term()}
  def request_for_task(task, opts \\ []) do
    Config.defaults(opts)
    |> then(&agent_run_request(task, &1))
  end

  defp agent_run_request(task, config) do
    task_ref = task_ref(task, config)

    AgentRunRequest.new(%{
      tenant_ref: config.tenant_ref,
      installation_ref: config.installation_ref,
      subject_ref: config.subject_ref,
      actor_ref: config.actor_ref,
      profile_bundle: LocalProfile.bundle!(),
      tool_catalog_ref: config.tool_catalog_ref,
      budget_ref: config.budget_ref,
      recall_scope_ref: config.recall_scope_ref,
      idempotency_key: config.idempotency_key,
      trace_id: config.trace_id,
      correlation_id: config.correlation_id,
      submission_dedupe_key: config.submission_dedupe_key,
      initial_input_ref: task_ref,
      params: %{
        profile_ref: config.profile_ref,
        run_ref: "run://stack-coder/#{config.submission_dedupe_key}",
        session_ref: config.session_ref,
        workspace_ref: config.workspace_ref,
        worker_ref: config.worker_ref,
        authority_context_ref: config.authority_context_ref,
        artifact_policy_ref: config.artifact_policy_ref,
        release_manifest_ref: config.release_manifest_ref,
        fixture_script: config.fixture_script,
        max_turns: config.max_turns
      }
    })
  end

  defp task_ref(%{} = task, config),
    do: Map.get(task, "input_ref") || Map.get(task, :input_ref) || config.task_ref

  defp task_ref(task, config) when is_binary(task), do: task |> stable_ref(config.task_ref)
  defp task_ref(_task, config), do: config.task_ref

  defp stable_ref(task, fallback) do
    if String.trim(task) == "" do
      fallback
    else
      "input://stack-coder/task/" <> hash_suffix(task)
    end
  end

  defp read_detail(context, run_ref, projection, config) do
    HeadlessSurface.run_detail(
      context,
      run_ref,
      %{agent_loop_projection: projection, subject_ref: config.subject_ref},
      backend: @backend
    )
  end

  defp appkit_opts(opts) do
    opts
    |> Keyword.take([:agent_loop_runtime])
    |> Keyword.put_new(:backend, @backend)
    |> Keyword.put_new(:agent_loop_runtime, @runtime)
  end

  defp write_artifacts!(run, receipt, config, opts) do
    run_dir = Path.join(config.output_root, hash_suffix(run.future.run_ref))

    artifacts = %{
      "projection" => Path.join(run_dir, "projection.json"),
      "events" => Path.join(run_dir, "events.json"),
      "receipt" =>
        Keyword.get(opts, :receipt_path, Path.join(run_dir, "#{Receipt.receipt_name()}.json"))
    }

    File.mkdir_p!(run_dir)

    File.write!(
      artifacts["projection"],
      Jason.encode!(present_projection(run.projection), pretty: true) <> "\n"
    )

    File.write!(
      artifacts["events"],
      Jason.encode!(Presenter.present_events(run.detail.events), pretty: true) <> "\n"
    )

    Receipt.write!(receipt, artifacts["receipt"])

    artifacts
  end

  defp present_projection(projection) do
    projection
    |> Map.from_struct()
    |> Map.drop([:__struct__])
    |> sanitize_projection()
  end

  defp sanitize_projection(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp sanitize_projection(%_{} = value), do: value |> Map.from_struct() |> sanitize_projection()

  defp sanitize_projection(%{} = value) do
    Map.new(value, fn {key, val} -> {to_string(key), sanitize_projection(val)} end)
  end

  defp sanitize_projection(values) when is_list(values),
    do: Enum.map(values, &sanitize_projection/1)

  defp sanitize_projection(value), do: value

  defp hash_suffix(value) do
    :crypto.hash(:sha256, value)
    |> Base.encode16(case: :lower)
    |> binary_part(0, 16)
  end
end

defmodule StackCoder.BootstrapWorker do
  @moduledoc "StackCoder bootstrap worker for Chassis-aware startup."
  use GenServer

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(opts) do
    if Keyword.get(opts, :enabled?, Application.get_env(:stack_coder, :bootstrap_on_start?, true)) do
      case bootstrap(opts) do
        {:ok, state} -> {:ok, state}
        {:error, reason} -> {:stop, {:bootstrap_failed, reason}}
      end
    else
      {:ok, %{enabled?: false}}
    end
  end

  @spec bootstrap(keyword()) :: {:ok, map()} | {:error, term()}
  def bootstrap(opts \\ []) do
    case Keyword.get(opts, :bootstrap) do
      {module, function, extra_args}
      when is_atom(module) and is_atom(function) and is_list(extra_args) ->
        apply(module, function, [opts | extra_args])

      fun when is_function(fun, 1) ->
        fun.(opts)

      nil ->
        config = StackCoder.Config.defaults(opts)

        {:ok,
         %{
           installation_ref: config.installation_ref,
           tenant_ref: config.tenant_ref,
           bootstrap: :local_appkit_config
         }}
    end
  end
end

defmodule StackCoder.ChassisRegistration do
  @moduledoc "Registers StackCoder with Chassis through AppKit.SpatialGateway."
  use GenServer

  alias AppKit.SpatialGateway

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(opts) do
    case register(opts) do
      {:ok, state} -> {:ok, state}
      {:error, reason} -> {:stop, {:chassis_registration_failed, reason}}
    end
  end

  @spec register(keyword()) :: {:ok, map()} | {:error, term()}
  def register(opts \\ []) when is_list(opts) do
    app_atom = Keyword.get(opts, :app_atom, :stack_coder)
    git_sha = Keyword.get(opts, :release_sha) || read_release_sha()

    with {:ok, profile_ref} <- SpatialGateway.get_active_profile(opts) do
      register_opts =
        Keyword.merge(opts,
          tenant_ref: tenant_ref(opts),
          installation_ref: installation_ref(opts),
          profile_ref: profile_ref,
          environment: environment(opts),
          release_version: release_version()
        )

      case SpatialGateway.register_deployed_app(app_atom, git_sha, register_opts) do
        {:ok, receipt_ref} ->
          {:ok,
           %{
             app_atom: app_atom,
             git_sha: git_sha,
             profile_ref: profile_ref,
             receipt_ref: receipt_ref,
             standalone: false
           }}

        {:error, reason} when reason in [:standalone, :registry_unavailable] ->
          {:ok,
           %{
             app_atom: app_atom,
             git_sha: git_sha,
             profile_ref: profile_ref,
             receipt_ref: nil,
             standalone: true
           }}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp read_release_sha do
    path = Application.app_dir(:stack_coder, "priv/release_sha.txt")

    case File.read(path) do
      {:ok, sha} -> String.trim(sha)
      _ -> System.get_env("RELEASE_SHA", "unknown")
    end
  end

  defp release_version do
    :stack_coder
    |> Application.spec(:vsn)
    |> to_string()
  end

  defp tenant_ref(opts),
    do: Keyword.get(opts, :tenant_ref, StackCoder.Config.defaults(opts).tenant_ref)

  defp installation_ref(opts),
    do: Keyword.get(opts, :installation_ref, StackCoder.Config.defaults(opts).installation_ref)

  defp environment(opts) do
    case Keyword.get(opts, :environment) || System.get_env("CHASSIS_ENV", "dev") do
      :prod -> :prod
      "prod" -> :prod
      _ -> :dev
    end
  end
end

defmodule StackCoder.VirtualServerSupervisor do
  @moduledoc "StackCoder virtual server supervisor."
  use Supervisor

  alias AppKit.SpatialGateway
  alias StackCoder.Topology

  def start_link(opts \\ []), do: Supervisor.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(opts) do
    app_atom = Keyword.fetch!(opts, :app_atom)
    node_atom = Keyword.get(opts, :node, node())

    with {:ok, profile_ref} <- SpatialGateway.get_active_profile(opts),
         {:ok, virtual_servers} <- Topology.virtual_servers_for(app_atom, profile_ref, node_atom) do
      children = Enum.flat_map(virtual_servers, &child_specs_for(&1, opts))
      Supervisor.init(children, strategy: :one_for_one)
    else
      {:error, reason} ->
        raise ArgumentError, "cannot resolve StackCoder virtual servers: #{inspect(reason)}"
    end
  end

  @spec child_specs_for(atom(), keyword()) :: [
          Supervisor.child_spec() | module() | {module(), term()}
        ]
  def child_specs_for(virtual_server, opts \\ []) do
    child_specs =
      Keyword.get(opts, :child_specs) ||
        Application.get_env(:stack_coder, :virtual_server_child_specs, %{})

    child_specs
    |> Map.get(virtual_server, default_child_specs_for(virtual_server))
    |> Enum.filter(&available_child_spec?/1)
  end

  defp default_child_specs_for(:vs_jido_integration), do: [StackCoder.ConnectorPack]
  defp default_child_specs_for(_unknown), do: []

  defp available_child_spec?(module) when is_atom(module), do: child_module_available?(module)

  defp available_child_spec?({module, _arg}) when is_atom(module),
    do: child_module_available?(module)

  defp available_child_spec?(%{start: {module, :start_link, _args}}) when is_atom(module),
    do: child_module_available?(module)

  defp available_child_spec?(_other), do: false

  defp child_module_available?(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :start_link, 1)
  end
end

defmodule StackCoder.Topology do
  @moduledoc "StackCoder Chassis profile topology."

  alias Chassis.Stack.ProfileResolver

  @spec virtual_servers_for(:stack_coder | :extravaganza, String.t(), atom()) ::
          {:ok, [atom()]} | {:error, term()}
  def virtual_servers_for(app_atom, profile_ref, node_atom)
      when app_atom in [:stack_coder, :extravaganza] and is_binary(profile_ref) and
             is_atom(node_atom) do
    with {:ok, resolved} <- ProfileResolver.resolve(profile_ref, current_env()) do
      node_str = Atom.to_string(node_atom)

      virtual_servers =
        resolved.placements
        |> Enum.filter(&node_matches?(&1.node_name_pattern, node_str))
        |> Enum.flat_map(& &1.virtual_servers)
        |> filter_for_app(app_atom)
        |> Enum.uniq()

      {:ok, virtual_servers}
    end
  end

  defp node_matches?("monolith@*", _node_str), do: true

  defp node_matches?(pattern, node_str) do
    prefix = String.replace_suffix(pattern, "@*", "@")
    String.starts_with?(node_str, prefix)
  end

  defp filter_for_app(vs_list, :stack_coder), do: vs_list
  defp filter_for_app(vs_list, :extravaganza), do: vs_list

  defp current_env do
    case System.get_env("CHASSIS_ENV", "dev") do
      "prod" -> :prod
      _ -> :dev
    end
  end
end

defmodule StackCoder.AgentIntake do
  @moduledoc "Builds StackCoder agent-run requests and submits them through AppKit."

  alias AppKit.Core.AgentIntake.AgentRunRequest

  def submit(request, opts \\ [])

  @spec submit(map(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def submit(request, opts) when is_map(request) and is_list(opts) do
    with {:ok, actor_ref} <- required_opt(opts, :actor_ref),
         {:ok, attrs} <- request_attrs(request, actor_ref, opts),
         {:ok, appkit_request} <- AgentRunRequest.new(attrs),
         {:ok, context} <- StackCoder.AppKitContext.new(context_opts(request, opts)),
         {:ok, result} <- AppKit.AgentIntake.start_agent_run(context, appkit_request, opts),
         {:ok, run_ref} <- run_ref(result) do
      {:ok, run_ref}
    end
  end

  def submit(_request, _opts), do: {:error, :invalid_stack_coder_request}

  defp request_attrs(request, actor_ref, opts) do
    with {:ok, tenant_ref} <- required_request(request, :tenant_ref),
         {:ok, installation_ref} <- required_request(request, :installation_ref),
         {:ok, user_prompt} <- required_request(request, :user_prompt),
         {:ok, repo_path} <- required_request(request, :repo_path) do
      nonce =
        hash([tenant_ref, installation_ref, user_prompt, repo_path, System.unique_integer()])

      {:ok,
       %{
         tenant_ref: tenant_ref,
         installation_ref: installation_ref,
         subject_ref: "subject://stack-coder/run/" <> nonce,
         actor_ref: actor_ref,
         profile_bundle: StackCoder.LocalProfile.bundle!(),
         tool_catalog_ref:
           value(request, :tool_catalog_ref, "tool-catalog://stack-coder/default"),
         budget_ref: value(request, :budget_ref, "budget://stack-coder/" <> hash(tenant_ref)),
         recall_scope_ref: "recall://stack-coder/codebase",
         idempotency_key: Keyword.get(opts, :idempotency_key, "idem:stack-coder:" <> nonce),
         trace_id: Keyword.get(opts, :trace_id, "trace://stack-coder/" <> nonce),
         correlation_id: Keyword.get(opts, :correlation_id, "corr://stack-coder/" <> nonce),
         submission_dedupe_key: "dedupe:stack-coder:" <> hash(user_prompt),
         initial_input_ref: "input://stack-coder/prompt/" <> hash(user_prompt),
         effect_governance_mode: :staging_live,
         params: %{
           "repo_path_ref" => "repo://stack-coder/path/" <> hash(repo_path),
           "context_refs" => value(request, :context_refs, [])
         }
       }}
    end
  end

  defp context_opts(request, opts) do
    opts
    |> Keyword.put(
      :tenant_ref,
      value(request, :tenant_ref, StackCoder.Config.defaults(opts).tenant_ref)
    )
    |> Keyword.put(
      :installation_ref,
      value(request, :installation_ref, StackCoder.Config.defaults(opts).installation_ref)
    )
  end

  defp required_opt(opts, key) do
    case Keyword.get(opts, key) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, {:missing_option, key}}
    end
  end

  defp required_request(request, key) do
    case value(request, key, nil) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, {:missing_request_key, key}}
    end
  end

  defp value(request, key, default) do
    Map.get(request, key, Map.get(request, Atom.to_string(key), default))
  end

  defp run_ref(%{run_ref: run_ref}) when is_binary(run_ref), do: {:ok, run_ref}
  defp run_ref(%{ref: run_ref}) when is_binary(run_ref), do: {:ok, run_ref}
  defp run_ref(run_ref) when is_binary(run_ref), do: {:ok, run_ref}
  defp run_ref(other), do: {:error, {:missing_run_ref, other}}

  defp hash(parts) when is_list(parts), do: parts |> Enum.join(":") |> hash()

  defp hash(value) do
    :crypto.hash(:sha256, to_string(value))
    |> Base.encode16(case: :lower)
    |> binary_part(0, 24)
  end
end

defmodule StackCoder.ConnectorPack do
  @moduledoc "Supervises configured StackCoder connector adapters when present."

  use Supervisor

  @connector_roles [
    :source_control,
    :repository_host,
    :issue_tracker,
    :model_primary,
    :model_secondary,
    :local_model
  ]

  def start_link(opts \\ []), do: Supervisor.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(opts) do
    children =
      Keyword.get(opts, :connector_specs) ||
        Application.get_env(:stack_coder, :connector_specs, [])

    Supervisor.init(children, strategy: :one_for_one)
  end

  @spec connectors() :: [atom()]
  def connectors, do: @connector_roles
end

defmodule StackCoder.DeploymentManifest do
  @moduledoc "Loads StackCoder Chassis service-spec manifests from priv/profiles."

  @manifest_dir Path.expand("../../priv/profiles", __DIR__)

  @spec all() :: {:ok, [map()]} | {:error, term()}
  def all do
    @manifest_dir
    |> Path.join("*.json")
    |> Path.wildcard()
    |> Enum.sort()
    |> Enum.map(&load_file/1)
    |> collect()
  end

  @spec load(String.t()) :: {:ok, map()} | {:error, term()}
  def load(profile_ref) when is_binary(profile_ref) do
    all()
    |> case do
      {:ok, manifests} ->
        case Enum.find(manifests, &(&1["profile_ref"] == profile_ref)) do
          nil -> {:error, :unknown_profile}
          manifest -> {:ok, manifest}
        end

      error ->
        error
    end
  end

  defp load_file(path) do
    with {:ok, body} <- File.read(path),
         {:ok, manifest} <- Jason.decode(body) do
      {:ok, manifest}
    else
      {:error, reason} -> {:error, {path, reason}}
    end
  end

  defp collect(results) do
    Enum.reduce_while(results, {:ok, []}, fn
      {:ok, manifest}, {:ok, acc} -> {:cont, {:ok, [manifest | acc]}}
      {:error, reason}, _acc -> {:halt, {:error, reason}}
    end)
    |> case do
      {:ok, manifests} -> {:ok, Enum.reverse(manifests)}
      error -> error
    end
  end
end

defmodule StackCoder.BootstrapWorker do
  @moduledoc "StackCoder bootstrap worker for Chassis-aware startup."
  use GenServer

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(opts), do: {:ok, opts}
end

defmodule StackCoder.ChassisRegistration do
  @moduledoc "Registers StackCoder with AppKit.SpatialGateway."
  use GenServer

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(opts), do: {:ok, Keyword.put(opts, :profile_ref, StackCoder.Topology.active_profile())}
end

defmodule StackCoder.VirtualServerSupervisor do
  @moduledoc "StackCoder virtual server supervisor."
  use Supervisor

  def start_link(opts \\ []), do: Supervisor.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_opts), do: Supervisor.init([], strategy: :one_for_one)
end

defmodule StackCoder.Topology do
  @moduledoc "StackCoder Chassis profile topology."

  @spec active_profile() :: String.t()
  def active_profile do
    if Code.ensure_loaded?(AppKit.SpatialGateway) do
      case apply(AppKit.SpatialGateway, :get_active_profile, []) do
        {:ok, %{profile_ref: profile_ref}} -> profile_ref
        _other -> System.get_env("CHASSIS_DEPLOYMENT_PROFILE", "profile:monolith")
      end
    else
      System.get_env("CHASSIS_DEPLOYMENT_PROFILE", "profile:monolith")
    end
  end

  @spec virtual_servers_for(String.t(), :dev | :prod, keyword()) :: [atom()]
  def virtual_servers_for("profile:monolith", _env, _opts), do: [:vs_app_kit, :vs_mezzanine]

  def virtual_servers_for(_profile_ref, _env, _opts),
    do: [:vs_stack_coder_agent, :vs_stack_coder_connectors]
end

defmodule StackCoder.AgentIntake do
  @moduledoc "AppKit AgentIntake bridge facade."
  def submit(request), do: {:ok, Map.put(request, :submitted?, true)}
end

defmodule StackCoder.ConnectorPack do
  @moduledoc "Connector pack registry for StackCoder."
  def list, do: [:agent_shell, :review_worker, :patch_worker, :analysis_worker, :workspace_worker]
end

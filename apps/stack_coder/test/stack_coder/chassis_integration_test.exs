defmodule StackCoder.ChassisIntegrationTest do
  use ExUnit.Case, async: false

  alias AppKit.Core.AgentIntake.AgentRunRequest
  alias AppKit.SpatialGateway.Request

  @all_virtual_servers [
    :vs_app_kit,
    :vs_mezzanine,
    :vs_outer_brain,
    :vs_citadel,
    :vs_jido_integration,
    :vs_execution_plane,
    :vs_secrets_plane,
    :vs_observability
  ]

  defmodule SpatialBackend do
    def handle(%Request.GetActiveProfile{}, opts),
      do: {:ok, Keyword.fetch!(opts, :active_profile)}

    def handle(%Request.RegisterDeployedApp{} = request, opts) do
      send(Keyword.fetch!(opts, :test_pid), {:registered, request, opts})
      {:ok, "receipt:appkit:stack-coder:test"}
    end
  end

  defmodule AgentBackend do
    def start_agent_run(_context, %AgentRunRequest{} = request, opts) do
      send(Keyword.fetch!(opts, :test_pid), {:agent_request, request, opts})
      {:ok, %{run_ref: "run://stack-coder/test"}}
    end
  end

  defmodule FailingBootstrap do
    def call(_opts), do: {:error, :installation_surface_down}
  end

  defmodule TestChild do
    use GenServer

    def start_link(opts), do: GenServer.start_link(__MODULE__, opts)
    def init(opts), do: {:ok, opts}
  end

  test "bootstrap worker calls the configured bootstrap implementation and stops on failure" do
    assert {:stop, {:bootstrap_failed, :installation_surface_down}} =
             StackCoder.BootstrapWorker.init(bootstrap: {FailingBootstrap, :call, []})
  end

  test "registration calls SpatialGateway with release and deployment context" do
    assert {:ok, state} =
             StackCoder.ChassisRegistration.register(
               active_profile: "profile:maximal-decoupled",
               spatial_gateway_backend: SpatialBackend,
               test_pid: self(),
               tenant_ref: "tenant:stack-coder",
               installation_ref: "installation:stack-coder:test",
               release_sha: "def456",
               environment: :prod
             )

    assert state.receipt_ref == "receipt:appkit:stack-coder:test"
    assert state.profile_ref == "profile:maximal-decoupled"

    assert_receive {:registered, request, opts}
    assert request.app_atom == :stack_coder
    assert request.git_sha == "def456"
    assert opts[:tenant_ref] == "tenant:stack-coder"
    assert opts[:installation_ref] == "installation:stack-coder:test"
    assert opts[:profile_ref] == "profile:maximal-decoupled"
    assert opts[:environment] == :prod
  end

  test "topology resolves Chassis profile placements by node pattern" do
    assert {:ok, servers} =
             StackCoder.Topology.virtual_servers_for(
               :stack_coder,
               "profile:monolith",
               :"monolith@127.0.0.1"
             )

    assert Enum.sort(servers) == Enum.sort(@all_virtual_servers)

    assert {:ok, [:vs_app_kit, :vs_observability]} =
             StackCoder.Topology.virtual_servers_for(
               :stack_coder,
               "profile:decoupled-cockpit-2",
               :appkit@vps1
             )

    assert {:ok,
            [
              :vs_mezzanine,
              :vs_outer_brain,
              :vs_citadel,
              :vs_jido_integration,
              :vs_execution_plane,
              :vs_secrets_plane
            ]} =
             StackCoder.Topology.virtual_servers_for(
               :stack_coder,
               "profile:decoupled-cockpit-2",
               :stack@vps2
             )
  end

  test "virtual server supervisor maps resolved servers to configured child specs" do
    assert {:ok, {_, children}} =
             StackCoder.VirtualServerSupervisor.init(
               app_atom: :stack_coder,
               active_profile: "profile:decoupled-cockpit-2",
               node: :appkit@vps1,
               spatial_gateway_backend: SpatialBackend,
               child_specs: %{
                 vs_app_kit: [{TestChild, name: :gateway_child}],
                 vs_observability: [{TestChild, name: :observability_child}]
               },
               test_pid: self()
             )

    assert [
             %{
               id: TestChild,
               start: {TestChild, :start_link, [[name: :gateway_child]]}
             },
             %{
               id: TestChild,
               start: {TestChild, :start_link, [[name: :observability_child]]}
             }
           ] = children
  end

  test "agent intake builds a typed AppKit request without raw prompt or repo path and delegates to AppKit" do
    request = %{
      tenant_ref: "tenant://stack-coder/acme",
      installation_ref: "installation://stack-coder/acme",
      repo_path: "/home/acme/private-repo",
      user_prompt: "refactor the payment adapter",
      context_refs: ["context://issue/123"]
    }

    assert {:ok, "run://stack-coder/test"} =
             StackCoder.AgentIntake.submit(request,
               actor_ref: "actor://stack-coder/operator",
               backend: AgentBackend,
               test_pid: self()
             )

    assert_receive {:agent_request, %AgentRunRequest{} = appkit_request, _opts}
    assert appkit_request.tenant_ref == "tenant://stack-coder/acme"
    assert appkit_request.installation_ref == "installation://stack-coder/acme"
    assert appkit_request.actor_ref == "actor://stack-coder/operator"
    assert appkit_request.initial_input_ref =~ "input://stack-coder/prompt/"
    assert appkit_request.params["repo_path_ref"] =~ "repo://stack-coder/path/"
    refute inspect(appkit_request) =~ "refactor the payment adapter"
    refute inspect(appkit_request) =~ "/home/acme/private-repo"
  end

  test "profile manifests contain service specs with virtual server placement" do
    root = Path.expand("../../priv/profiles", __DIR__)

    for file <- ~w(monolith decoupled_cockpit_2 ternary_split_3 maximal_decoupled) do
      manifest = root |> Path.join(file <> ".json") |> File.read!() |> Jason.decode!()

      assert manifest["app_atom"] == "stack_coder"
      assert is_binary(manifest["profile_ref"])
      assert [_ | _] = manifest["service_specs"]

      assert Enum.all?(manifest["service_specs"], fn service ->
               is_binary(service["service_spec_ref"]) and
                 is_binary(service["node_name_pattern"]) and
                 is_binary(service["systemd_unit_name"]) and
                 match?([_ | _], service["virtual_servers"])
             end)
    end
  end
end

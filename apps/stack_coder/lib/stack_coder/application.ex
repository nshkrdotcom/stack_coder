defmodule StackCoder.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    Supervisor.start_link(
      [
        StackCoder.BootstrapWorker,
        {StackCoder.ChassisRegistration, app_atom: :stack_coder},
        {StackCoder.VirtualServerSupervisor, app_atom: :stack_coder}
      ],
      strategy: :rest_for_one,
      name: StackCoder.Supervisor
    )
  end
end

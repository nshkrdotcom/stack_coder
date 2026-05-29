defmodule StackCoder.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    Supervisor.start_link(
      [
        StackCoder.BootstrapWorker,
        StackCoder.ChassisRegistration,
        StackCoder.VirtualServerSupervisor
      ],
      strategy: :rest_for_one,
      name: StackCoder.Supervisor
    )
  end
end

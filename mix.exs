defmodule StackCoderWorkspace.MixProject do
  use Mix.Project

  def project do
    [
      app: :stack_coder_workspace,
      version: "0.1.0",
      elixir: "~> 1.19",
      deps: [],
      aliases: aliases()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  def cli do
    [preferred_envs: [ci: :test]]
  end

  defp aliases do
    [
      ci: ["cmd --cd apps/stack_coder mix ci"]
    ]
  end
end

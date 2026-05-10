unless Code.ensure_loaded?(DependencySources) do
  Code.require_file("build_support/dependency_sources.exs", __DIR__)
end

defmodule StackCoderWorkspace.MixProject do
  use Mix.Project

  def project do
    [
      app: :stack_coder_workspace,
      version: "0.1.0",
      elixir: "~> 1.19",
      deps: DependencySources.deps(__DIR__),
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

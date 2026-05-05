defmodule StackCoder.MixProject do
  use Mix.Project

  @source_url "https://github.com/nshkrdotcom/stack_coder"

  def project do
    [
      app: :stack_coder,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      docs: docs(),
      name: "StackCoder",
      description: "Provider-free local Profile B host over AppKit",
      source_url: @source_url,
      homepage_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def cli do
    [
      preferred_envs: [
        ci: :test,
        "profile_b.local": :test
      ]
    ]
  end

  defp aliases do
    [
      ci: [
        "deps.get",
        "format --check-formatted",
        "compile --warnings-as-errors",
        "test",
        "profile_b.local",
        "cmd --cd ../../../app_kit mix app_kit.no_bypass --root ../stack_coder --profile product --profile hazmat --include apps/stack_coder/lib/**/*.ex --exclude apps/stack_coder/lib/stack_coder/runtime_adapter.ex"
      ],
      "profile_b.local": ["test --only profile_b_local_offline"]
    ]
  end

  defp docs do
    [
      main: "readme",
      logo: "assets/stack_coder.svg",
      extras: ["README.md", "CHANGELOG.md", "LICENSE"]
    ]
  end

  defp deps do
    [
      {:app_kit_core, path: "../../../app_kit/core/app_kit_core"},
      {:mezzanine_workflow_runtime, path: "../../../mezzanine/core/workflow_runtime"},
      {:jido_integration_contracts,
       path: "../../../jido_integration/core/contracts", override: true},
      {:jason, "~> 1.4"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40.1", only: :dev, runtime: false}
    ]
  end
end

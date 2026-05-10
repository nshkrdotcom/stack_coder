unless Code.ensure_loaded?(DependencySources) do
  Code.require_file("build_support/dependency_sources.exs", __DIR__)
end

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
      package: package(),
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
      DependencySources.dep(:app_kit_core, __DIR__),
      DependencySources.dep(:mezzanine_workflow_runtime, __DIR__),
      jido_integration_contracts_dep(),
      {:jason, "~> 1.4"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40.1", only: :dev, runtime: false}
    ]
  end

  defp jido_integration_contracts_dep do
    dep = DependencySources.dep(:jido_integration_contracts, __DIR__)

    if hex_packaging_task?() do
      dep
    else
      merge_dep_opts(dep, override: true)
    end
  end

  defp hex_packaging_task? do
    Enum.any?(System.argv(), &(&1 in ["hex.build", "hex.publish"]))
  end

  defp merge_dep_opts({app, dep_opts}, opts) when is_list(dep_opts),
    do: {app, Keyword.merge(dep_opts, opts)}

  defp merge_dep_opts({app, requirement}, opts), do: {app, requirement, opts}

  defp merge_dep_opts({app, requirement, dep_opts}, opts),
    do: {app, requirement, Keyword.merge(dep_opts, opts)}

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib assets build_support mix.exs README.md CHANGELOG.md LICENSE)
    ]
  end
end

project_root = Path.expand("..", __DIR__)
siblings_root = Path.expand("../../..", project_root)

%{
  deps: %{
    app_kit_core: %{
      path: Path.join(siblings_root, "app_kit/core/app_kit_core"),
      github: %{repo: "nshkrdotcom/app_kit", branch: "main", subdir: "core/app_kit_core"},
      hex: "~> 0.1.0",
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    app_kit_chassis_bridge: %{
      path: Path.join(siblings_root, "app_kit/bridges/chassis_bridge"),
      github: %{repo: "nshkrdotcom/app_kit", branch: "main", subdir: "bridges/chassis_bridge"},
      hex: "~> 0.1.0",
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    chassis_stack: %{
      path: Path.join(siblings_root, "chassis/core/chassis_stack"),
      github: %{repo: "nshkrdotcom/chassis", branch: "main", subdir: "core/chassis_stack"},
      hex: "~> 0.1.0",
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    mezzanine_workflow_runtime: %{
      path: Path.join(siblings_root, "mezzanine/core/workflow_runtime"),
      github: %{
        repo: "nshkrdotcom/mezzanine",
        branch: "main",
        subdir: "core/workflow_runtime"
      },
      hex: "~> 0.1.0",
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    jido_integration_contracts: %{
      path: Path.join(siblings_root, "jido_integration/core/contracts"),
      github: %{repo: "agentjido/jido_integration", branch: "main", subdir: "core/contracts"},
      hex: "~> 0.1.0",
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    }
  }
}

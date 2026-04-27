defmodule StackCoder.Config do
  @moduledoc "Local Profile B defaults."

  @default_trace_id "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  @default_tenant_ref "tenant://stack-coder/local"
  @default_installation_ref "installation://stack-coder/local"
  @default_subject_ref "subject://stack-coder/local-task"
  @default_actor_ref "actor://stack-coder/local-operator"
  @default_release_manifest_ref "release-manifest://stack-coder/local-fixture/v1"

  @spec defaults(keyword()) :: map()
  def defaults(opts \\ []) do
    task_ref = Keyword.get(opts, :task_ref, "input://stack-coder/local-task")

    %{
      tenant_ref: Keyword.get(opts, :tenant_ref, @default_tenant_ref),
      installation_ref: Keyword.get(opts, :installation_ref, @default_installation_ref),
      subject_ref: Keyword.get(opts, :subject_ref, @default_subject_ref),
      actor_ref: Keyword.get(opts, :actor_ref, @default_actor_ref),
      trace_id: Keyword.get(opts, :trace_id, @default_trace_id),
      correlation_id: Keyword.get(opts, :correlation_id, "correlation://stack-coder/local"),
      idempotency_key:
        Keyword.get(opts, :idempotency_key, "agent-run:start:stack-coder:local:fixture"),
      submission_dedupe_key:
        Keyword.get(opts, :submission_dedupe_key, "stack-coder-local-fixture"),
      task_ref: task_ref,
      budget_ref: Keyword.get(opts, :budget_ref, "budget://stack-coder/local-fixture"),
      recall_scope_ref:
        Keyword.get(opts, :recall_scope_ref, "recall://stack-coder/local-fixture"),
      tool_catalog_ref:
        Keyword.get(opts, :tool_catalog_ref, "tool-catalog://stack-coder/fixture-coding-tools"),
      profile_ref: Keyword.get(opts, :profile_ref, "profile://stack-coder/local-fixture/v1"),
      session_ref: Keyword.get(opts, :session_ref, "session://stack-coder/local-fixture"),
      workspace_ref: Keyword.get(opts, :workspace_ref, "workspace://stack-coder/local-fixture"),
      worker_ref: Keyword.get(opts, :worker_ref, "worker://stack-coder/local-fixture"),
      authority_context_ref:
        Keyword.get(
          opts,
          :authority_context_ref,
          "authority-context://stack-coder/local-fixture"
        ),
      artifact_policy_ref:
        Keyword.get(opts, :artifact_policy_ref, "artifact-policy://stack-coder/local-fixture"),
      release_manifest_ref:
        Keyword.get(opts, :release_manifest_ref, @default_release_manifest_ref),
      fixture_script: Keyword.get(opts, :fixture_script, "success_first_try"),
      max_turns: Keyword.get(opts, :max_turns, 1),
      output_root: Keyword.get(opts, :output_root, "tmp/stack_coder_runs")
    }
  end
end

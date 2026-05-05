defmodule StackCoder.LocalProfileTest do
  use ExUnit.Case, async: true

  alias StackCoder.{LocalPack, LocalProfile, RuntimePolicy}

  test "declares provider-free local profile slots" do
    assert {:ok, bundle} = LocalProfile.bundle()

    assert LocalPack.profile_ref() == "profile://stack-coder/local-fixture/v1"
    assert bundle.source_profile_ref == :synthetic_task
    assert bundle.runtime_profile_ref == :fixture_runtime
    assert bundle.tool_scope_ref == :fixture_coding_tools
    assert bundle.evidence_profile_ref == :file_artifact_refs
    assert bundle.publication_profile_ref == :none
    assert bundle.review_profile_ref == :none
    assert bundle.memory_profile_ref == :none
    assert bundle.projection_profile_ref == :local_headless_readback
  end

  test "bounds task states provider modes target modes readback events and operator actions" do
    assert :ok = RuntimePolicy.validate_task_state("completed")
    assert {:error, {:unknown_task_state, "paused"}} = RuntimePolicy.validate_task_state("paused")

    assert :ok = RuntimePolicy.validate_provider_selection_mode(:provider_free_local)

    assert {:error, {:unknown_provider_selection_mode, :ambient_provider}} =
             RuntimePolicy.validate_provider_selection_mode(:ambient_provider)

    assert :ok = RuntimePolicy.validate_target_mode(:appkit_local_profile_b)

    assert {:error, {:unknown_target_mode, :direct_sandbox}} =
             RuntimePolicy.validate_target_mode(:direct_sandbox)

    assert :ok = RuntimePolicy.validate_readback_event_kind("run.terminal")

    assert {:error, {:unknown_readback_event_kind, "run.paused"}} =
             RuntimePolicy.validate_readback_event_kind("run.paused")

    assert :ok = RuntimePolicy.validate_operator_action_kind(:cancel)

    assert {:error, {:unknown_operator_action_kind, :force_restart}} =
             RuntimePolicy.validate_operator_action_kind(:force_restart)
  end
end

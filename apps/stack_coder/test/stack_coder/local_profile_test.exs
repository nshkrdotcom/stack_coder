defmodule StackCoder.LocalProfileTest do
  use ExUnit.Case, async: true

  alias StackCoder.{LocalPack, LocalProfile}

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
end

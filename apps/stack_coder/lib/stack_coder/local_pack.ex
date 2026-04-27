defmodule StackCoder.LocalPack do
  @moduledoc "Profile B local pack defaults."

  @spec profile_ref() :: String.t()
  def profile_ref, do: "profile://stack-coder/local-fixture/v1"

  @spec source_profile_ref() :: atom()
  def source_profile_ref, do: :synthetic_task

  @spec runtime_profile_ref() :: atom()
  def runtime_profile_ref, do: :fixture_runtime

  @spec tool_scope_ref() :: atom()
  def tool_scope_ref, do: :fixture_coding_tools

  @spec evidence_profile_ref() :: atom()
  def evidence_profile_ref, do: :file_artifact_refs

  @spec publication_profile_ref() :: atom()
  def publication_profile_ref, do: :none

  @spec review_profile_ref() :: atom()
  def review_profile_ref, do: :none

  @spec memory_profile_ref() :: atom()
  def memory_profile_ref, do: :none

  @spec projection_profile_ref() :: atom()
  def projection_profile_ref, do: :local_headless_readback
end

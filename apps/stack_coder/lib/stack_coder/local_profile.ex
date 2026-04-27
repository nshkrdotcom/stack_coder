defmodule StackCoder.LocalProfile do
  @moduledoc "Profile B AppKit profile bundle."

  alias AppKit.Core.Substrate.ProfileBundle
  alias StackCoder.LocalPack

  @spec bundle() :: {:ok, ProfileBundle.t()} | {:error, term()}
  def bundle do
    ProfileBundle.new(%{
      source_profile_ref: LocalPack.source_profile_ref(),
      runtime_profile_ref: LocalPack.runtime_profile_ref(),
      tool_scope_ref: LocalPack.tool_scope_ref(),
      evidence_profile_ref: LocalPack.evidence_profile_ref(),
      publication_profile_ref: LocalPack.publication_profile_ref(),
      review_profile_ref: LocalPack.review_profile_ref(),
      memory_profile_ref: LocalPack.memory_profile_ref(),
      projection_profile_ref: LocalPack.projection_profile_ref()
    })
  end

  @spec bundle!() :: ProfileBundle.t()
  def bundle! do
    case bundle() do
      {:ok, bundle} ->
        bundle

      {:error, reason} ->
        raise ArgumentError, "invalid StackCoder local profile: #{inspect(reason)}"
    end
  end

  @spec dump() :: map()
  def dump, do: ProfileBundle.dump(bundle!())
end

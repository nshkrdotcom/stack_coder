defmodule StackCoder.AppKitContext do
  @moduledoc "Builds the AppKit request context for local Profile B runs."

  alias AppKit.Core.RequestContext
  alias StackCoder.Config

  @spec new(keyword()) :: {:ok, RequestContext.t()} | {:error, term()}
  def new(opts \\ []) do
    config = Config.defaults(opts)

    RequestContext.new(%{
      trace_id: config.trace_id,
      actor_ref: ref_parts(config.actor_ref, :human),
      tenant_ref: ref_parts(config.tenant_ref),
      installation_ref: %{
        id: ref_id(config.installation_ref),
        pack_slug: "stack_coder_local",
        pack_version: "0.1.0",
        status: :active
      },
      request_id: "request://stack-coder/local-fixture",
      idempotency_key: config.idempotency_key,
      metadata: %{
        program_id: "stack-coder-local",
        work_class_id: "local-fixture-task",
        installation_revision: 1,
        activation_epoch: 1,
        lease_epoch: 1
      }
    })
  end

  defp ref_parts(ref, kind \\ nil) do
    %{id: ref_id(ref)}
    |> maybe_put(:kind, kind)
  end

  defp ref_id(ref) do
    ref
    |> String.split("://", parts: 2)
    |> List.last()
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

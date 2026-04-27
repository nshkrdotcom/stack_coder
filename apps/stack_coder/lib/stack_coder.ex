defmodule StackCoder do
  @moduledoc """
  StackCoder local Profile B host.

  The public entrypoints delegate to `StackCoder.LocalHost`, which enters the
  agent runtime through AppKit surfaces.
  """

  alias StackCoder.LocalHost

  @spec run(String.t() | map(), keyword()) :: {:ok, map()} | {:error, term()}
  def run(task, opts \\ []), do: LocalHost.run(task, opts)

  @spec detail(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def detail(run_ref, opts \\ []), do: LocalHost.detail(run_ref, opts)

  @spec events(String.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def events(run_ref, opts \\ []), do: LocalHost.events(run_ref, opts)

  @spec cancel(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def cancel(run_ref, opts \\ []), do: LocalHost.cancel(run_ref, opts)
end

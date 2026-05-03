defmodule StackCoder.LocalE2ETest do
  use ExUnit.Case, async: false

  alias StackCoder.{LocalHost, Presenter, Receipt, RuntimeAdapter}

  @tag :profile_b_local_offline
  test "runs a provider-free local turn through AppKit and writes receipt artifacts" do
    RuntimeAdapter.reset!()

    receipt_path =
      Path.join([
        "tmp",
        "test_receipts",
        "#{System.unique_integer([:positive])}",
        "agentic_substrate_local_e2e_v1.json"
      ])

    assert {:ok, run} =
             LocalHost.run("explain current repo layout",
               idempotency_key: "agent-run:start:stack-coder:test",
               submission_dedupe_key: "stack-coder-test",
               receipt_path: receipt_path,
               json?: true
             )

    assert run.future.accepted?
    assert run.future.run_ref == "run://stack-coder/stack-coder-test"
    assert run.detail.runtime_row.state == "completed"
    assert Enum.any?(run.detail.events, &(&1.event_kind == "run.terminal"))
    assert run.receipt["mechanisms"] == ["M1", "M2"]
    assert run.receipt["agentic_core_proven?"]
    assert run.receipt["provider_network_access?"] == false
    assert run.receipt["linear_used?"] == false
    assert run.receipt["github_used?"] == false
    assert run.receipt["codex_used?"] == false
    assert run.receipt["memory_profile_ref"] == "none"
    assert run.receipt["runtime_event_count"] == length(run.detail.events)
    assert Receipt.validate(run.receipt) == :ok
    assert File.exists?(receipt_path)

    assert {:ok, decoded} = receipt_path |> File.read!() |> Jason.decode()
    assert decoded["receipt_name"] == "agentic_substrate_local_e2e_v1"
  end

  @tag :profile_b_local_offline
  test "same idempotency key resolves to the same run ref" do
    RuntimeAdapter.reset!()

    opts = [
      idempotency_key: "agent-run:start:stack-coder:same",
      submission_dedupe_key: "stack-coder-same",
      output_root: "tmp/idempotency"
    ]

    assert {:ok, first} = LocalHost.run("same task", opts)
    assert {:ok, second} = LocalHost.run("same task", opts)

    assert first.future.run_ref == second.future.run_ref
  end

  @tag :profile_b_local_offline
  test "detail and events read through AppKit headless readback" do
    RuntimeAdapter.reset!()

    assert {:ok, run} =
             LocalHost.run("inspect readback",
               idempotency_key: "agent-run:start:stack-coder:readback",
               submission_dedupe_key: "stack-coder-readback",
               output_root: "tmp/readback"
             )

    assert {:ok, detail} = LocalHost.detail(run.future.run_ref)
    assert detail["schema_ref"] == "runtime_readback/run_detail.v1"
    assert detail["state"] == "completed"

    assert {:ok, events} = LocalHost.events(run.future.run_ref)
    assert Enum.any?(events, &(&1["event_kind"] == "run.terminal"))
  end

  @tag :profile_b_local_offline
  test "cancel uses the AppKit agent intake surface" do
    RuntimeAdapter.reset!()

    assert {:ok, run} =
             LocalHost.run("cancel target",
               idempotency_key: "agent-run:start:stack-coder:cancel",
               submission_dedupe_key: "stack-coder-cancel",
               output_root: "tmp/cancel"
             )

    assert {:ok, command} = LocalHost.cancel(run.future.run_ref)
    assert command["command_kind"] == "cancel"
    assert command["accepted?"] == true
    assert command["command_ref"] == "command://cancel/run-stack-coder-stack-coder-cancel"
  end

  test "CLI JSON output matches presenter readback shape" do
    RuntimeAdapter.reset!()

    assert {:ok, run} =
             LocalHost.run("json output",
               idempotency_key: "agent-run:start:stack-coder:json",
               submission_dedupe_key: "stack-coder-json",
               output_root: "tmp/json",
               json?: true
             )

    rendered = Presenter.render(run.presentation, json?: true)
    assert {:ok, decoded} = Jason.decode(rendered)
    assert decoded["schema_ref"] == "stack_coder/local_run.v1"
    assert decoded["run_ref"] == run.future.run_ref
  end

  test "repo-owned code avoids pattern engine APIs" do
    assert_no_source_hits(pattern_engine_tokens(), code_files())
  end

  test "repo-owned code avoids dynamic atom conversion APIs" do
    assert_no_source_hits(atom_conversion_tokens(), code_files())
  end

  test "runtime modules do not import lower runtime internals or provider selectors" do
    lib_files = runtime_files()

    assert lib_files != []

    Enum.each(lib_files, fn path ->
      contents = File.read!(path)

      assert_no_source_hits(
        ["Mezzanine.", "Citadel.", "Jido.Integration", "ExecutionPlane", "OuterBrain."],
        [{path, contents}],
        "bypasses AppKit"
      )

      assert_no_source_hits(
        ["Linear", "Codex", "GitHub", "OpenAI", "Anthropic", "claude", "gpt-"],
        [{path, contents}],
        "leaks provider vocabulary"
      )
    end)
  end

  defp code_files do
    Path.wildcard("{lib,test}/**/*.{ex,exs}")
    |> Enum.map(&{&1, File.read!(&1)})
  end

  defp runtime_files do
    Path.wildcard("lib/**/*.ex")
  end

  defp pattern_engine_tokens do
    [
      "Reg" <> "ex",
      "~" <> "r",
      ":r" <> "e.",
      "String.mat" <> "ch",
      "Reg" <> "Exp",
      "reg" <> "exp",
      "re.comp" <> "ile",
      "import r" <> "e"
    ]
  end

  defp atom_conversion_tokens do
    [
      "String.to_" <> "atom",
      "String.to_existing_" <> "atom",
      "binary_to_" <> "atom",
      "binary_to_existing_" <> "atom",
      "list_to_" <> "atom",
      "list_to_existing_" <> "atom"
    ]
  end

  defp assert_no_source_hits(tokens, files, reason \\ "contains forbidden source token") do
    hits =
      for {path, contents} <- files,
          token <- tokens,
          String.contains?(contents, token) do
        {path, token}
      end

    assert hits == [], "#{inspect(hits)} #{reason}"
  end
end

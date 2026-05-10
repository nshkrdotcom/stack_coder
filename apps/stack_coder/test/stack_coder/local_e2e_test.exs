defmodule StackCoder.LocalE2ETest do
  use ExUnit.Case, async: false

  alias StackCoder.{LocalHost, Presenter, Receipt, RuntimeAdapter}

  @ambient_authority_values [
    {"STACK_CODER_PROVIDER_CREDENTIAL", "sk-stack-coder-env-provider"},
    {"STACK_CODER_BASE_URL", "https://env.stack-coder.invalid"},
    {"STACK_CODER_AUTH_ROOT", "/home/env/.stack-coder-auth"},
    {"STACK_CODER_TOOL_PERMISSIONS", "env-tool-permissions"},
    {"STACK_CODER_TARGET_REF", "target://env/stack-coder"},
    {"STACK_CODER_WORKSPACE_SECRET", "workspace-env-secret"}
  ]

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

  test "repo-owned code avoids dynamic quoted atom interpolation" do
    hits =
      for {path, contents} <- code_files(),
          quoted_atom_interpolation?(contents) do
        path
      end

    assert hits == [], "#{inspect(hits)} contains dynamic quoted atom interpolation"
  end

  test "ambient authority values cannot select StackCoder task authority" do
    assert {:ok, request} =
             LocalHost.request_for_task("ambient value proof",
               idempotency_key: "agent-run:start:stack-coder:ambient-values",
               submission_dedupe_key: "stack-coder-ambient-values"
             )

    encoded = inspect(request)

    Enum.each(@ambient_authority_values, fn {_name, value} ->
      refute String.contains?(encoded, value)
    end)
  end

  test "unmanaged env authority inputs are rejected before task dispatch" do
    for {field, value} <- authority_fields() do
      assert {:error, {:unmanaged_env_authority, ^field}} =
               LocalHost.request_for_task(%{
                 "objective" => "reject unmanaged env",
                 Atom.to_string(field) => value
               })

      assert {:error, {:unmanaged_env_authority, ^field}} =
               LocalHost.request_for_task("reject unmanaged env", [{field, value}])
    end
  end

  @tag :profile_b_local_offline
  test "readback artifacts redact env-derived values supplied by the caller" do
    secret = "stack-coder-env-readback-secret"

    RuntimeAdapter.reset!()

    output_root =
      Path.join([
        "tmp",
        "env_redaction",
        "#{System.unique_integer([:positive])}"
      ])

    receipt_path = Path.join(output_root, "receipt.json")

    assert {:ok, run} =
             LocalHost.run("redaction proof",
               idempotency_key: "agent-run:start:stack-coder:redaction",
               submission_dedupe_key: "stack-coder-redaction",
               subject_ref: "subject://stack-coder/#{secret}",
               output_root: output_root,
               receipt_path: receipt_path,
               redaction_values: [secret],
               json?: true
             )

    presentation = Presenter.render(run.presentation, json?: true)
    refute String.contains?(presentation, secret)
    assert String.contains?(presentation, "[REDACTED]")

    for {_name, path} <- run.artifact_paths do
      contents = File.read!(path)

      refute String.contains?(contents, secret)
    end
  end

  test "runtime modules do not import lower runtime internals or provider selectors" do
    lib_files = runtime_files()

    assert lib_files != []

    Enum.each(lib_files, fn path ->
      contents = File.read!(path)

      assert_no_source_hits(
        lower_runtime_tokens(path),
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

  defp lower_runtime_tokens("lib/stack_coder/runtime_adapter.ex") do
    ["Citadel.", "Jido.Integration", "ExecutionPlane", "OuterBrain."]
  end

  defp lower_runtime_tokens(_path) do
    ["Mezzanine.", "Citadel.", "Jido.Integration", "ExecutionPlane", "OuterBrain."]
  end

  defp code_files do
    source_files(["lib", "test"], [".ex", ".exs"])
    |> Enum.map(&{&1, File.read!(&1)})
  end

  defp runtime_files do
    source_files(["lib"], [".ex"])
  end

  defp source_files(roots, extensions) do
    roots
    |> Enum.flat_map(&walk_files/1)
    |> Enum.filter(&source_extension?(&1, extensions))
    |> Enum.sort()
  end

  defp walk_files(path) do
    cond do
      File.dir?(path) ->
        path
        |> File.ls!()
        |> Enum.flat_map(&walk_files(Path.join(path, &1)))

      File.regular?(path) ->
        [path]

      true ->
        []
    end
  end

  defp source_extension?(path, extensions) do
    Enum.any?(extensions, &String.ends_with?(path, &1))
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
      "list_to_existing_" <> "atom",
      "Module." <> "concat"
    ]
  end

  defp quoted_atom_interpolation?(contents) do
    case next_quoted_atom(contents) do
      :nomatch ->
        false

      {quoted, remaining} ->
        String.contains?(quoted, "\#{") or quoted_atom_interpolation?(remaining)
    end
  end

  defp next_quoted_atom(contents) do
    case :binary.match(contents, ":\"") do
      :nomatch ->
        :nomatch

      {start, 2} ->
        after_marker = binary_part(contents, start + 2, byte_size(contents) - start - 2)
        quoted_atom_parts(after_marker)
    end
  end

  defp quoted_atom_parts(after_marker) do
    case :binary.match(after_marker, "\"") do
      :nomatch ->
        :nomatch

      {finish, 1} ->
        quoted = binary_part(after_marker, 0, finish)
        remaining_start = finish + 1

        remaining =
          binary_part(after_marker, remaining_start, byte_size(after_marker) - remaining_start)

        {quoted, remaining}
    end
  end

  defp authority_fields do
    [
      provider_credential: "sk-stack-coder-env-provider",
      provider_credentials: "sk-stack-coder-env-provider",
      api_key: "sk-stack-coder-env-provider",
      base_url: "https://env.stack-coder.invalid",
      auth_root: "/home/env/.stack-coder-auth",
      tool_permissions: "env-tool-permissions",
      target_ref: "target://env/stack-coder",
      workspace_secret: "workspace-env-secret"
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

defmodule StackCoder.Redaction do
  @moduledoc false

  @marker "[REDACTED]"

  @spec marker() :: String.t()
  def marker, do: @marker

  @spec values(term()) :: [String.t()]
  def values(values) do
    values
    |> List.wrap()
    |> Enum.filter(&is_binary/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  @spec redact(term(), term()) :: term()
  def redact(value, redaction_values) do
    redact_value(value, values(redaction_values))
  end

  defp redact_value(value, []), do: value

  defp redact_value(%DateTime{} = value, _values), do: value

  defp redact_value(%_{} = value, values) do
    value
    |> Map.from_struct()
    |> redact_value(values)
  end

  defp redact_value(%{} = value, values) do
    Map.new(value, fn {key, val} -> {redact_value(key, values), redact_value(val, values)} end)
  end

  defp redact_value(values, redaction_values) when is_list(values) do
    Enum.map(values, &redact_value(&1, redaction_values))
  end

  defp redact_value(value, values) when is_binary(value) do
    Enum.reduce(values, value, &replace_literal/2)
  end

  defp redact_value(value, _values), do: value

  defp replace_literal(secret, value) do
    if String.contains?(value, secret) do
      secret
      |> then(&String.split(value, &1))
      |> Enum.join(@marker)
    else
      value
    end
  end
end

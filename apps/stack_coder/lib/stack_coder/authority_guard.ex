defmodule StackCoder.AuthorityGuard do
  @moduledoc false

  @authority_fields [
    :provider_credential,
    :provider_credentials,
    :credential,
    :credential_ref,
    :api_key,
    :token,
    :base_url,
    :auth_root,
    :tool_permissions,
    :target_ref,
    :workspace_secret,
    :workspace_secret_ref
  ]

  @authority_field_names Map.new(@authority_fields, fn field -> {Atom.to_string(field), field} end)

  @spec reject_unmanaged_input(term(), keyword()) ::
          :ok | {:error, {:unmanaged_env_authority, atom()}}
  def reject_unmanaged_input(task, opts) do
    with :ok <- reject_value(task) do
      reject_value(opts)
    end
  end

  defp reject_value(%{} = map) do
    Enum.reduce_while(map, :ok, fn {key, value}, :ok ->
      case authority_field(key) do
        nil -> continue_or_halt(reject_value(value))
        field -> {:halt, {:error, {:unmanaged_env_authority, field}}}
      end
    end)
  end

  defp reject_value(values) when is_list(values) do
    if Keyword.keyword?(values) do
      reject_keyword(values)
    else
      reject_list(values)
    end
  end

  defp reject_value(_value), do: :ok

  defp reject_keyword(values) do
    Enum.reduce_while(values, :ok, fn {key, value}, :ok ->
      case authority_field(key) do
        nil -> continue_or_halt(reject_value(value))
        field -> {:halt, {:error, {:unmanaged_env_authority, field}}}
      end
    end)
  end

  defp reject_list(values) do
    Enum.reduce_while(values, :ok, fn value, :ok ->
      continue_or_halt(reject_value(value))
    end)
  end

  defp continue_or_halt(:ok), do: {:cont, :ok}
  defp continue_or_halt({:error, _reason} = error), do: {:halt, error}

  defp authority_field(field) when is_atom(field) do
    if field in @authority_fields, do: field
  end

  defp authority_field(field) when is_binary(field) do
    field
    |> String.trim()
    |> String.downcase()
    |> normalize_separator("-")
    |> normalize_separator(" ")
    |> then(&Map.get(@authority_field_names, &1))
  end

  defp authority_field(_field), do: nil

  defp normalize_separator(value, separator) do
    value
    |> String.split(separator)
    |> Enum.join("_")
  end
end

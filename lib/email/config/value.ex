defmodule Rivet.Email.Config.Value do
  # true json
  @behaviour Ecto.Type

  @type t :: binary() | list(binary())

  @impl true
  def type, do: :map

  defp config_value(v) when is_binary(v), do: {:ok, v}

  # email name/addr tuple
  defp config_value([n, e]) when is_binary(n) and is_binary(e), do: {:ok, [n, e]}

  defp config_value(_), do: :error

  @impl true
  def cast(v), do: config_value(v)
  @impl true
  def load(v), do: config_value(v)
  @impl true
  def dump(v), do: config_value(v)
  @impl true
  def equal?(a, b), do: a == b
  @impl true
  def embed_as(_), do: :dump
end

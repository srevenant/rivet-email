defmodule Rivet.Email.Template.Helpers do
  @doc """
  useful function to normalize different ways email addrs may come in.

  iex> email_addr("this@that")
  "this@that"
  iex> email_addr({10, "this@that"})
  "this@that"
  iex> email_addr(%{address: "this@that"})
  "this@that"
  """
  def email_addr(addr) when is_binary(addr), do: addr
  def email_addr({_, addr}), do: addr
  def email_addr(%{address: addr}) when is_binary(addr), do: addr
end

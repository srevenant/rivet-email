defmodule Rivet.Email.Template.Helpers do
  def email_addr(addr) when is_binary(addr), do: addr
  def email_addr({_, addr}), do: addr
  def email_addr(%{address: addr}) when is_binary(addr), do: addr
end

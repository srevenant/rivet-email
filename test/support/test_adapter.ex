defmodule Rivet.Email.Swoosh.Adapter.Test do
  use Swoosh.Adapter
  require Logger

  def deliver(%Swoosh.Email{to: [{_, eaddr}], subject: subj} = email, _config) do
    if eaddr === "error@error" do
      {:error, "test error"}
    else
      Logger.warning("Testing send message to #{inspect(eaddr)}", subject: subj)
      Rivet.Email.log_email(email)

      {:ok, "test delivered"}
    end
  end
end

defmodule Rivet.Email.Swoosh.Adapter.Test do
  use Swoosh.Adapter
  require Logger

  def deliver(%Swoosh.Email{to: [{_, eaddr}], subject: subj} = email, _config) do
    # for pid <- pids() do
    #   send(pid, {:email, email})
    # end
    #
    if eaddr === "error@error" do
      {:error, "test error"}
    else
      Logger.warning("Testing send message to #{inspect(eaddr)}", subject: subj)
      Rivet.Email.log_email(email)

      {:ok, "test delivered"}
    end
  end

  #
  # def deliver_many(emails, _config) do
  #   # for pid <- pids() do
  #   #   send(pid, {:emails, emails})
  #   # end
  #
  #   responses = for _email <- emails, do: "test delivered"
  #
  #   {:ok, responses}
  # end
  # Essentially finds all of the processes that tried to send an email (in the test)
  # and sends an email to that process.
  # defp pids do
  #   if pid = Application.get_env(:swoosh, :shared_test_process) do
  #     [pid]
  #   else
  #     Enum.uniq([self() | List.wrap(Process.get(:"$callers"))])
  #   end
  # end
end

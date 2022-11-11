defmodule Rivet.Email.Example.Template do
  @behaviour Rivet.Email.Template

  @impl Rivet.Email.Template
  def generate(recip, attrs) do
    {:ok, "test subject", "<p>Welcome #{recip.user.name}<p>This is a test from #{attrs.email_from}"}
  end
end

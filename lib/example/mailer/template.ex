defmodule Rivet.Email.Example.Mailer.Template do
  use Rivet.Email.Template

  # override generate to use local data instead of db template
  @impl Rivet.Email.Template
  def generate(recip, attrs) do
    {:ok, "test subject",
     "<p>Welcome #{recip.user.name}<p>This is a test from #{attrs.email_from}"}
  end
end

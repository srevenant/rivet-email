defmodule Rivet.Email.Test do
  use ExUnit.Case
  import ExUnit.CaptureLog
  alias Rivet.Email.Example.Mailer

  doctest Rivet.Email.Template, import: true

  test "Rivet.Email.convert_case/3" do
    assert capture_log(fn ->
             Mailer.send(Mailer.User.mock(), Mailer.Template, tester: "testing")
           end) =~ """
           Subject: test subject\n--- html\n<html><body><p>Welcome Doctor Who<p>This is a test from noreply@example.com</body></html>\n--- text\n\r\nWelcome Doctor Who\r\nThis is a test from noreply@example.com
           """
  end
end

defmodule Rivet.Email.Test do
  use ExUnit.Case
  import ExUnit.CaptureLog
  alias Rivet.Email.Example.Mailer

  doctest Rivet.Email.Template, import: true

  test "send via template" do
    assert capture_log(fn ->
             assert {:ok, ["email disabled"]} =
                      Mailer.Template.sendto(Mailer.User.mock(), tester: "testing")
           end) =~ """
           Subject: test subject\n--- html\n<html><body><p>Welcome Doctor Who<p>This is a test from noreply@example.com</body></html>\n--- text\n\r\nWelcome Doctor Who\r\nThis is a test from noreply@example.com
           """
  end
end

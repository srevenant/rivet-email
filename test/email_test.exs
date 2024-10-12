defmodule Rivet.Email.Test do
  use ExUnit.Case
  import ExUnit.CaptureLog
  alias Rivet.Email.Example.Mailer

  doctest Rivet.Email, import: true

  test "send via template" do
    assert capture_log(fn ->
             assert {:ok, ["email disabled"]} =
                      Mailer.Template.sendto(Mailer.User.mock(), tester: "testing")
           end) =~ ~r/Subject: test subject/
  end
end

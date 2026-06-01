defmodule Test.Rivet.Email.SendTest do
  use Test.Support.Email.Case
  import ExUnit.CaptureLog
  alias Rivet.Email.Example.Mailer

  describe "tests" do
    setup do
      assert {:ok, _} =
               Rivet.Email.Template.create(%{name: "//CONFIG/narf", data: "{\"boop\": 1}"})

      :ok
    end

    test "send via template" do
      assert capture_log(fn ->
               assert {:ok, ["test delivered"]} =
                        Mailer.Template.sendto(Mailer.User.mock(), tester: "testing")
             end) =~ ~r/Subject: test subject/
    end

    test "send" do
      %{emails: [em]} = Mailer.User.mock()
      erred = %{em | address: "error@error"}

      assert {:error, "Sender email address is missing from assigns (@email_from)"} =
               Mailer.sendto(em, Mailer.Template)

      from = [email_from: "nobody@nobody"]

      assert {:error, "Cannot send email without recipient!"} =
               Mailer.sendto([], Mailer.Template, from)

      assert {:error, "test error", _} =
               Mailer.sendto(erred, Mailer.Template, from, ["narf"])

      ## something about the test adapter isn't supporting the name+email structure like this,
      ## so skip the test for now...
      # assert {:ok, ["test delivered"]} =
      #          Mailer.sendto(em, Mailer.Template, [email_from: ["boop", "nobody@nobody"]])
      assert {:ok, ["test delivered"]} = Mailer.sendto(em, Mailer.Template, from, [])
    end
  end
end

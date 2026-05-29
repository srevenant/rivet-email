defmodule Rivet.Email.Test do
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

    test "config" do
      assert {:error, "no email template for: site"} =
               Mailer.Configurator.get_key("nope", [:boop])

      assert {:ok, 1} = Mailer.Configurator.get_key("narf", [:boop])

      assert {:error, "no email template for: site"} =
               Mailer.Configurator.get_key("narf", [:nope])

      assert {:ok, %{boop: 1}} = Mailer.Configurator.get_config("narf")
      assert {:ok, s} = Rivet.Email.Template.create(%{name: "//CONFIG/site", data: "{\"no\": 0}"})
      assert {:error, :not_found} = Mailer.Configurator.get_key("site", [:boop])
      assert {:ok, %{no: 0}} = Mailer.Configurator.get_config("site")
      Rivet.Email.Template.delete(s)
    end
  end
end

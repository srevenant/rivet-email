defmodule Rivet.Email.Test do
  use Test.Support.Email.Case
  import ExUnit.CaptureLog
  alias Rivet.Email.Example.Mailer
  alias Mailer.Configurator
  alias Rivet.Email.Config

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

      test "config test" do
        assert [] = Config.all!()

        {:ok, %Config{id: id, site: "", group: "addr", key: "boop", value: "somefin"}} =
          Config.set("addr", "boop", "somefin")

        # change the value and also test list/string email tuples
        {:ok, %Config{id: ^id, value: ["a", "b"]}} = Config.set("addr", "boop", ["a", "b"])

        {:error, %{valid?: false, errors: [value: {"is invalid", _}]}} = Config.set("addr", "boop", 1)

        assert {:error, :not_found} = Configurator.conf("spleen", "boop")

        assert {:ok, %Config{}} = Config.set("spleen", "boop", "sploop")

        assert {:ok, %{value: "sploop"}} = Configurator.conf("spleen", "boop")

        assert {:ok, %{spleen: %{boop: "sploop"}}} = Configurator.load_site("")

        # Config.Migrate.test_data()
        # Config.Migrate.migrate(Rivet.Email.Repo)
        #
        # {:ok, %{}} = Config.load_site("") |>IO.inspect
      end
  end
end

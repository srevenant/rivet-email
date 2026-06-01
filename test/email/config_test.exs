defmodule Test.Rivet.Email.ConfigTest do
  use Test.Support.Email.Case
  alias Rivet.Email.Example.Mailer
  alias Mailer.Configurator
  alias Rivet.Email.Config

  test "config test" do
    # clear cache of any other tests data
    Configurator.clear()
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
  end
end

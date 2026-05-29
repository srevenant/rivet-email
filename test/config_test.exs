defmodule Rivet.Email.ConfigTest do
  use Test.Support.Email.Case
  alias Rivet.Email.Config

  test "config test" do
    assert [] = Config.all!()

    {:ok, %Config{id: id, site: "", group: "addr", key: "boop", value: "somefin"}} =
      Config.set("addr", "boop", "somefin")

    # change the value and also test list/string email tuples
    {:ok, %Config{id: ^id, value: ["a", "b"]}} = Config.set("addr", "boop", ["a", "b"])

    {:error, %{valid?: false, errors: [value: {"is invalid", _}]}} = Config.set("addr", "boop", 1)
  end
end

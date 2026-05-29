defmodule Rivet.Email.ConfigTest do
  use Test.Support.Email.Case
  alias Rivet.Email.Config

  test "config test" do
    # # Temp
    # Config.all!() |>
    assert [] = Config.all!()
    {:ok, %Config{site: "", group: "addr", key: "boop", data: %{"asdf" => "1"}}} =
      Config.create(%{site: "", group: "addr", key: "boop", data: %{"asdf" => "1"}})
  end
end

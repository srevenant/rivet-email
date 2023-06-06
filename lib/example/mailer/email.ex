defmodule Rivet.Email.Example.Mailer.Email do
  defstruct id: "", address: "", user: %Rivet.Email.Example.Mailer.User{}, verified: true

  # coveralls-ignore-start
  def preload(e, _), do: {:ok, %{e | user: Rivet.Email.Example.Mailer.User.mock()}}
  def one(_), do: {:ok, mock()}
  # coveralls-ignore-end

  def mock() do
    %__MODULE__{
      id: "BOGUS001-fB40-4EEF-B352-307C280604C1",
      address: "who@the.tardis"
    }
  end
end

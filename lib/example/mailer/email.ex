defmodule Rivet.Email.Example.Mailer.Email do
  alias Rivet.Email.Example.Mailer
  defstruct id: "", address: "", user: %Mailer.User{}, verified: true

  @type t :: %__MODULE__{
          id: String.t(),
          address: String.t(),
          user: Mailer.User.t(),
          verified: boolean()
        }

  # coveralls-ignore-start
  def preload(e, _), do: {:ok, %{e | user: Mailer.User.mock()}}
  def one(_), do: {:ok, mock()}
  # coveralls-ignore-end

  def mock() do
    %__MODULE__{
      id: "BOGUS001-fB40-4EEF-B352-307C280604C1",
      address: "who@the.tardis"
    }
  end
end

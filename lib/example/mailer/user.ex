defmodule Rivet.Email.Example.Mailer.User do
  defstruct id: "", name: "", emails: []

  # coveralls-ignore-start
  def preload(e, _), do: {:ok, e}
  def one(_), do: {:ok, mock()}
  # coveralls-ignore-end

  def mock() do
    %__MODULE__{
      id: "BOGUS000-fB40-4EEF-B352-307C280604C1",
      name: "Doctor Who",
      emails: [Rivet.Email.Example.Mailer.Email.mock()]
    }
  end
end

defmodule Test.Support.Email.Case do
  use ExUnit.CaseTemplate

  using do
    quote location: :keep do
      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      # import Rivet.Email.Case
      alias Rivet.Email.Repo
      alias Ecto.Changeset
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Rivet.Email.Repo, [])

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Rivet.Email.Repo, {:shared, self()})
    end

    :ok
  end
end

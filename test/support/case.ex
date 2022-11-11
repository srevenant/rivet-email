defmodule Rivet.Email.Case do
  use ExUnit.CaseTemplate

  using do
    quote location: :keep do
      import Rivet.Email.Case
    end
  end
end

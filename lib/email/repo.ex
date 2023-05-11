defmodule Rivet.Email.Repo do
  @moduledoc false
  use Ecto.Repo, otp_app: :rivet_email, adapter: Ecto.Adapters.Postgres
end

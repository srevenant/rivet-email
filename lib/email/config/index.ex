defmodule Rivet.Email.Config do
  use TypedEctoSchema
  use Rivet.Ecto.Model

  typed_schema "email_configs" do
    field(:site, :string, default: "")
    field(:group, :string)
    field(:key, :string)
    field(:data, :map)
    timestamps()
  end

  use Rivet.Ecto.Collection,
    not_found: :atom,
    required: [:group, :key],
    create: [:site],
    update: [:data],
    unique_constraints: [[:site, :group, :key]]
end

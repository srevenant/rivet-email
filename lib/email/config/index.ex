defmodule Rivet.Email.Config do
  use TypedEctoSchema
  use Rivet.Ecto.Model

  typed_schema "email_configs" do
    field(:site, :string, default: "")
    field(:group, :string)
    field(:key, :string)
    field(:value, __MODULE__.Value)
    timestamps()
  end

  def set(group, key, value, site \\ ""),
    do:
      replace(%{site: site, group: group, key: key, value: value},
        site: site,
        group: group,
        key: key
      )

  def load_site(site) do
    with {:ok, list} <- all(site: site) do
      {:ok,
       Enum.reduce(list, %{}, fn %{group: group, key: key, value: value}, map ->
         group = String.to_atom(group)
         key = String.to_atom(key)
         put_in(map, [Access.key(group, %{}), key], value)
       end)}
    end
  end

  use Rivet.Ecto.Collection,
    not_found: :atom,
    required: [:group, :key],
    create: [:site],
    update: [:value],
    unique_constraints: [[:site, :group, :key]]
end

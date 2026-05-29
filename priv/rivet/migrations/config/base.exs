defmodule Rivet.Email.Config.Migrations.Base do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:email_configs, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:site, :string, null: false)
      add(:group, :string, null: false)
      add(:key, :string, null: false)
      add(:data, :map, null: false)
      timestamps()
    end
    create(unique_index(:email_configs, [:site, :group, :key]))
  end

end

defmodule Rivet.Email.Templates.Migrations.Base do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:email_templates, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :string)
      add(:data, :string)
      timestamps()
    end
  end
end
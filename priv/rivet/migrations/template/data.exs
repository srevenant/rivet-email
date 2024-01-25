defmodule Rivet.Email.Template.Migrations.Data do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:email_template_data, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :string, null: false)
      add(:site, :string)
      add(:data, :map)
    end
  end
end

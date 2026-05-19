defmodule Rivet.Email.Template.Migrations.V01Index do
  @moduledoc false
  use Ecto.Migration

  def change do
    create_if_not_exists unique_index(:email_templates, [:name])
  end
end

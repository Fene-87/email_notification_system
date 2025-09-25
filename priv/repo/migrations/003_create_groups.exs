defmodule EmailNotificationSystem.Repo.Migrations.CreateGroups do
  use Ecto.Migration

  def change do
    create table(:groups, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :name, :string, null: false, size: 200
      add :description, :text
      add :is_active, :boolean, default: true, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:groups, [:user_id])
    create index(:groups, [:is_active])
    create unique_index(:groups, [:user_id, :name])
  end
end

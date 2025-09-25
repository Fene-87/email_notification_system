defmodule EmailNotificationSystem.Repo.Migrations.CreateContacts do
  use Ecto.Migration

  def change do
    create table(:contacts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :first_name, :string, null: false, size: 100
      add :last_name, :string, null: false, size: 100
      add :email_address, :string, null: false, size: 255
      add :phone_number, :string, size: 20
      add :is_active, :boolean, default: true, null: false
      add :tags, {:array, :string}, default: []

      timestamps(type: :utc_datetime)
    end

    create index(:contacts, [:user_id])
    create index(:contacts, [:email_address])
    create index(:contacts, [:is_active])
    create unique_index(:contacts, [:user_id, :email_address])
  end
end

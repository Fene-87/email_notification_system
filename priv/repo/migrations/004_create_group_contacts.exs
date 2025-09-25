defmodule EmailNotificationSystem.Repo.Migrations.CreateGroupContacts do
  use Ecto.Migration

  def change do
    create table(:group_contacts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :group_id, references(:groups, on_delete: :delete_all, type: :binary_id), null: false
      add :contact_id, references(:contacts, on_delete: :delete_all, type: :binary_id), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:group_contacts, [:group_id])
    create index(:group_contacts, [:contact_id])
    create unique_index(:group_contacts, [:group_id, :contact_id])
  end
end

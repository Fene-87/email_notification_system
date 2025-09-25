defmodule EmailNotificationSystem.Repo.Migrations.CreateEmails do
  use Ecto.Migration

  def change do
    create table(:emails, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :subject, :string, null: false
      add :body, :text, null: false
      add :from_email, :string, null: false
      add :reply_to, :string
      add :email_type, :string, default: "single", null: false
      add :priority, :integer, default: 5, null: false
      add :status, :string, default: "draft", null: false
      add :scheduled_at, :utc_datetime
      add :sent_at, :utc_datetime
      add :group_id, references(:groups, on_delete: :nilify_all, type: :binary_id)

      timestamps(type: :utc_datetime)
    end

    create index(:emails, [:user_id])
    create index(:emails, [:status])
    create index(:emails, [:email_type])
    create index(:emails, [:priority])
    create index(:emails, [:scheduled_at])
    create index(:emails, [:sent_at])
    create index(:emails, [:group_id])

    create constraint(:emails, :valid_email_type,
      check: "email_type IN ('single', 'bulk', 'group')")

    create constraint(:emails, :valid_status,
      check: "status IN ('draft', 'queued', 'sending', 'sent', 'failed', 'cancelled')")

    create constraint(:emails, :valid_priority,
      check: "priority >= 1 AND priority <= 10")
  end
end

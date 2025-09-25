defmodule EmailNotificationSystem.Repo.Migrations.CreateEmailRecipients do
  use Ecto.Migration

  def change do
    create table(:email_recipients, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email_id, references(:emails, on_delete: :delete_all, type: :binary_id), null: false
      add :contact_id, references(:contacts, on_delete: :delete_all, type: :binary_id)
      add :recipient_email, :string, null: false
      add :recipient_name, :string
      add :status, :string, default: "pending", null: false
      add :sent_at, :utc_datetime
      add :delivered_at, :utc_datetime
      add :opened_at, :utc_datetime
      add :clicked_at, :utc_datetime
      add :bounced_at, :utc_datetime
      add :error_message, :text
      add :retry_count, :integer, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:email_recipients, [:email_id])
    create index(:email_recipients, [:contact_id])
    create index(:email_recipients, [:status])
    create index(:email_recipients, [:sent_at])
    create index(:email_recipients, [:recipient_email])

    create constraint(:email_recipients, :valid_recipient_status,
      check: "status IN ('pending', 'sent', 'delivered', 'opened', 'clicked', 'bounced', 'failed')")
  end
end

defmodule EmailNotificationSystem.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :first_name, :string, null: false, size: 100
      add :last_name, :string, null: false, size: 100
      add :email_address, :string, null: false, size: 255
      add :msisdn, :string, null: false, size: 20
      add :password_hash, :string, null: false
      add :access_level, :string, default: "frontend", null: false
      add :plan_type, :string, default: "basic", null: false
      add :is_active, :boolean, default: true, null: false
      add :last_login_at, :utc_datetime
      add :email_verified, :boolean, default: false
      add :phone_verified, :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email_address])
    create unique_index(:users, [:msisdn])
    create index(:users, [:access_level])
    create index(:users, [:plan_type])
    create index(:users, [:is_active])
    create index(:users, [:inserted_at])

    # Add constraint for access levels
    create constraint(:users, :valid_access_level,
      check: "access_level IN ('frontend', 'admin', 'superuser')")

    # Add constraint for plan types
    create constraint(:users, :valid_plan_type,
      check: "plan_type IN ('basic', 'gold')")
  end
end

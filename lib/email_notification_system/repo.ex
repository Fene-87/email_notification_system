defmodule EmailNotificationSystem.Repo do
  use Ecto.Repo,
    otp_app: :email_notification_system,
    adapter: Ecto.Adapters.Postgres
end

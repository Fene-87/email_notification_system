import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :email_notification_system, EmailNotificationSystem.Repo,
  username: "marko",
  password: "root",
  hostname: "localhost",
  database: "email_notification_system_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :email_notification_system, EmailNotificationSystemWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "ZFJympQEI1f+1yMLW97Em0BO5ZOZI03NTyCFj4SWXH1XV/JTTTHY5pudQbYHqXmQ",
  server: false

# In test we don't send emails
config :email_notification_system, EmailNotificationSystem.Mailer, adapter: Swoosh.Adapters.Test

config :email_notification_system, Oban, testing: :manual, queues: false

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

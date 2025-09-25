import Config

config :email_notification_system,
  ecto_repos: [EmailNotificationSystem.Repo],
  generators: [binary_id: true]

config :email_notification_system, EmailNotificationSystemWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: EmailNotificationSystemWeb.ErrorHTML, json: EmailNotificationSystemWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: EmailNotificationSystem.PubSub,
  live_view: [signing_salt: "your-secret-salt"]

config :email_notification_system, EmailNotificationSystem.Mailer,
  adapter: Swoosh.Adapters.Local

# Oban configuration for priority queues
config :email_notification_system, Oban,
  repo: EmailNotificationSystem.Repo,
  queues: [emails: 5],
  plugins: [Oban.Plugins.Pruner]

config :esbuild,
  version: "0.17.11",
  email_notification_system: [
    args: ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :tailwind,
  version: "3.4.0",
  email_notification_system: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"

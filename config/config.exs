import Config

# Print only warnings and errors during test
config :logger, level: :warning

config :rivet, app: :rivet_email, repo: Rivet.Email.Repo

# This is set in your app, to allow other things to know what you've named your
# mail sender (the Rivet.Email module)
config :rivet_email,
  ecto_repos: [Rivet.Email.Repo],
  enabled: true,
  mailer: Rivet.Email.Example.Mailer,
  configurator: Rivet.Email.Example.Configurator,
  # a special row in the templates table with JSON/config data for all templates
  site_configs: "--config:site"

# See Swoosh Mailer docs for more information on this configuration
config :rivet_email, Rivet.Email.Example.Mailer.Backend, adapter: Rivet.Email.Swoosh.Adapter.Test
# adapter: Swoosh.Adapters.SMTP

config :ex_unit, capture_log: true

config :rivet_email, Rivet.Email.Repo,
  migration_repo: Rivet.Email.Repo,
  pool_size: 20,
  username: "postgres",
  password: "",
  database: "rivet_email_test",
  hostname: "localhost",
  log: false,
  pool: Ecto.Adapters.SQL.Sandbox

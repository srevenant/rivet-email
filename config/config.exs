import Config

config :logger, level: :info

config :rivet,
  repo: Rivet.Email.Repo,
  table_prefix: "",
  test: true

# This is set in your app, to allow other things to know what you've named your
# mail sender (the Rivet.Email module)
config :rivet_email,
  ecto_repos: [Rivet.Email.Repo],
  enabled: false,
  mailer: Rivet.Email.Example.Mailer,
  # a special row in the templates table with JSON/config data for all templates
  site_configs: "--config:site"

# See Swoosh Mailer docs for more information on this configuration
config :rivet_email, Rivet.Email.Example.Mailer.Backend,
  adapter: Swoosh.Adapters.SMTP,
  relay: "mail.example.com",
  hostname: "example.com",
  port: 25,
  tls: :if_available,
  retries: 2,
  no_mx_lookups: true,
  auth: :if_available

import_config "#{config_env()}.exs"

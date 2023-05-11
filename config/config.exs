import Config

config :logger, level: :info

config :rivet,
  repo: Rivet.Email.Repo,
  table_prefix: "",
  test: true

# this is where you define common things used in templates
config :rivet_email, :email,
  link_front: "http://localhost:3000",
  link_back: "http://localhost:4000",
  org: "Example Org",
  email_from: "noreply@example.com",
  email_sig: "Example Org"

# This is set in your app, to allow other things to know what you've named your
# mail sender (the Rivet.Email module)
config :rivet_email,
  ecto_repos: [Rivet.Email.Repo],
  enabled: false,
  mailer: Rivet.Email.Example.Mailer

# See BambooMailer docs for more information on this configuration
config :rivet_email, Rivet.Email.Example.Mailer.Backend,
  adapter: Bamboo.SMTPAdapter,
  server: "mail.example.com",
  hostname: "example.com",
  port: 25,
  tls: :if_available,
  retries: 2,
  no_mx_lookups: true,
  auth: :if_available

import_config "#{config_env()}.exs"

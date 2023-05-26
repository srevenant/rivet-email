import Config

# Print only warnings and errors during test
config :logger, level: :warn

config :ex_unit, capture_log: true

config :rivet_email,
  enabled: false,
  mailer: Rivet.Email.Example.Mailer

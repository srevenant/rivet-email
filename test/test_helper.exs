children = [
  {Rivet.Email.Repo, []},
  Rivet.Email.Example.Mailer.Configurator
]

Supervisor.start_link(children, strategy: :one_for_one, name: Test.Supervisor)

ExUnit.start(
  exclude: [:skip],
  capture_log: true,
  formatters: [JUnitFormatter, ExUnit.CLIFormatter]
)

Ecto.Adapters.SQL.Sandbox.mode(Rivet.Email.Repo, :auto)

ExUnit.start(capture_log: false)
{:ok, _} = Application.ensure_all_started(:ex_machina)

children = [
  {Rivet.Email.Repo, []},
  Rivet.Email.Example.Mailer.Configurator
]

Supervisor.start_link(children, strategy: :one_for_one, name: Test.Supervisor)

ExUnit.configure(exclude: [pending: true], formatters: [JUnitFormatter, ExUnit.CLIFormatter])
Faker.start()

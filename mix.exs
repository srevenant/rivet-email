defmodule Rivet.Email.MixProject do
  use Mix.Project

  def project do
    [
      app: :rivet_email,
      version: "1.0.0",
      elixir: "~> 1.13",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      source_url: "https://github.com/srevenant/rivet-email",
      docs: [
        main: "Rivet.Email",
        extras: ["README.md"]
      ],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test
      ],
      deps: deps(),
      dialyzer: [
        ignore_warnings: ".dialyzer_ignore.exs",
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
      ],
      aliases: [c: "compile"],
      package: package(),
      description: description()
    ]
  end

  def application do
    [
      env: [
        enabled: false,
        sender: Rivet.Email.Example
      ],
      extra_applications: [:logger, :timex, {:ex_unit, :optional}]
    ]
  end

  defp elixirc_paths(:test), do: ["example", "lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bamboo, "~> 1.4"},
      {:bamboo_smtp, "~> 2.1.0"},
      {:jason, "~> 1.0"},
      {:timex, "~> 3.6"},
      {:html_sanitize_ex, "~> 1.4"},
      {:excoveralls, "~> 0.14", only: :test, runtime: false},
      {:ex_machina, "~> 2.7.0", only: :test, runtime: false},
      {:faker, "~> 0.10", only: :test, runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:mix_test_watch, "~> 0.8", only: [:dev, :test], runtime: false}
    ]
  end

  defp description() do
    """
    Email handler with templates for Elixir, part of the Rivets Framework
    """
  end

  defp package() do
    [
      files: ~w(lib .formatter.exs mix.exs README* LICENSE*),
      licenses: ["AGPL-3.0-or-later"],
      links: %{"GitHub" => "https://github.com/srevenant/rivet-email"},
      source_url: "https://github.com/srevenant/rivet-email"
    ]
  end
end

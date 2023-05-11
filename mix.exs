defmodule Rivet.Email.MixProject do
  use Mix.Project

  def project do
    [
      app: :rivet_email,
      version: "1.0.3",
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
      extra_applications: [:logger, :timex, {:ex_unit, :optional}]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/lib"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # please alphabetize
      {:bamboo, "~> 1.4"},
      {:bamboo_smtp, "~> 2.1.0"},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:ex_machina, "~> 2.7.0", only: :test, runtime: false},
      {:excoveralls, "~> 0.14", only: :test, runtime: false},
      {:faker, "~> 0.10", only: :test, runtime: false},
      {:html_sanitize_ex, "~> 1.4"},
      {:jason, "~> 1.0"},
      {:mix_test_watch, "~> 0.8", only: [:dev, :test], runtime: false},
      {:rivet, "~> 1.0", git: "https://github.com/srevenant/rivet", branch: "template", override: true},
      {:timex, "~> 3.6"},
      {:transmogrify, "~> 1.1.0"}
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
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/srevenant/rivet-email"},
      source_url: "https://github.com/srevenant/rivet-email"
    ]
  end
end

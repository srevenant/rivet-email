defmodule RivetEmail.MixProject do
  use Mix.Project

  @source_url "https://github.com/srevenant/rivet-email"
  def project do
    [
      app: :rivet_email,
      version: "1.2.1",
      package: package(),
      elixir: "~> 1.13",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test,
        dialyzer: :test
      ],
      deps: deps(),
      dialyzer: [
        ignore_warnings: ".dialyzer_ignore.exs",
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
      ],
      xref: [exclude: List.wrap(Application.get_env(:rivet, :repo))],
      source_url: @source_url,
      docs: [main: "Rivet.Email"],
      aliases: [c: "compile"],
      description: description()
    ]
  end

  def application do
    [
      env: [
        rivet: [
          app: :rivet_email,
          base: "Rivet.Email",
          models_dir: "email"
        ]
      ],
      extra_applications: [:logger, :timex, {:ex_unit, :optional}]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # please alphabetize
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:ex_machina, "~> 2.7.0", only: :test, runtime: false},
      {:excoveralls, "~> 0.14", only: :test, runtime: false},
      {:faker, "~> 0.10", only: :test, runtime: false},
      {:gen_smtp, "~> 1.2.0"},
      {:html_sanitize_ex, "~> 1.4"},
      {:jason, "~> 1.0"},
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false},
      {:rivet, "~> 2.0", git: "https://github.com/srevenant/rivet.git", branch: "deps-update"},
      {:swoosh, "~> 1.9"},
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
      files: ~w(lib .formatter.exs mix.exs priv README* LICENSE*),
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url},
      source_url: @source_url
    ]
  end
end

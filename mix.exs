defmodule RivetEmail.MixProject do
  use Mix.Project

  @source_url "https://github.com/srevenant/rivet-email"
  def project do
    [
      app: :rivet_email,
      version: "1.0.7",
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
      rivet: [
        models_dir: "email",
        app_base: Rivet.Email
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
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:ex_machina, "~> 2.7.0", only: :test, runtime: false},
      {:excoveralls, "~> 0.14", only: :test, runtime: false},
      {:faker, "~> 0.10", only: :test, runtime: false},
      {:html_sanitize_ex, "~> 1.4"},
      {:jason, "~> 1.0"},
      {:mix_test_watch, "~> 0.8", only: [:dev, :test], runtime: false},
      {:rivet, "~> 1.0.6"},
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
      links: %{"GitHub" => @source_url},
      source_url: @source_url
    ]
  end
end

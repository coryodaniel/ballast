defmodule Ballast.MixProject do
  use Mix.Project

  def project do
    [
      app: :ballast,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test, "coveralls.travis": :test, "coveralls.html": :test],
      aliases: aliases(),
      docs: [
        extras: ["README.md"],
        main: "readme"
      ],
      dialyzer: [
        ignore_warnings: ".dialyzer_ignore.exs",
        list_unused_filters: true
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Ballast.Application, []}
    ]
  end

  defp aliases do
    [lint: ["format", "credo", "dialyzer"]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bonny, "~> 0.3"},
      {:jason, "~> 1.1"},

      # GoogleApi requires Poison 3, but doesnt include it in its deps :(
      # https://github.com/googleapis/elixir-google-api/issues/1232
      {:poison, "~> 3.1"},
      {:goth, "~> 1.0.1"},
      {:google_api_container, "~> 0.5"},
      {:google_api_compute, "~> 0.6"},

      # Dev deps
      {:mix_test_watch, "~> 0.8", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0.0-rc.4", only: :dev, runtime: false},
      {:ex_doc, "~> 0.20", only: :dev},
      {:credo, "~> 1.0.0", only: [:dev, :test], runtime: false},

      # Test Deps
      {:excoveralls, "~> 0.10", only: :test}
    ]
  end
end

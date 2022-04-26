defmodule Apa.MixProject do
  use Mix.Project

  @app :apa
  @version "0.1.0"

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Apa.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:amqp, "~> 3.1"},

      # JSON/YAML/Serialization
      {:jason, "~> 1.3"},
      {:yaml_elixir, "~> 2.8"},

      # Documentation
      {:ex_doc, ">= 0.0.0", only: :dev},

      # Code Quality
      # Static analysis
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      # Linting and best practices
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      # Tracing
      {:rexbug, ">= 1.0.0"}
    ]
  end
end

defmodule CalderaApi.MixProject do
  use Mix.Project

  def project do
    [
      app: :caldera_api,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {CalderaApi.Application, []},
      extra_applications: [:logger, :plug_cowboy]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.4", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:elixir_uuid, "~> 1.2"},
      {:ex_aws, "~> 2.1"},
      {:ex_aws_s3, "~> 2.1"},
      {:gnat, "~> 1.0"},
      {:hackney, "~> 1.17"},
      {:jason, "~> 1.2"},
      {:plug_cowboy, "~> 2.0"},
      {:poolboy, "~> 1.5.2"},
      {:redix, "~> 0.11"},
      {:sonix, git: "git://github.com/imerkle/sonix.git"}
    ]
  end
end

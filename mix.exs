defmodule Jumbo.Mixfile do
  use Mix.Project

  def project do
    [app: :jumbo,
     version: "0.0.1",
     elixir: "~> 1.3",
     elixirc_paths: elixirc_paths(Mix.env),
     description: "Jumbo Job Queue",
     maintainers: ["Marcin Lewandowski"],
     licenses: ["LGPL"],
     name: "Jumbo Core",
     source_url: "https://github.com/mspanc/jumbo",
     preferred_cli_env: [espec: :test],
     deps: deps]
  end


  def application do
    [applications: [
      :logger,
    ], mod: {Jumbo, []}]
  end


  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib",]


  defp deps do
    [
      {:espec, "~> 1.1.2", only: :test},
      {:ex_doc, "~> 0.14", only: :dev},
      {:uuid, "~> 1.1"},
    ]
  end
end

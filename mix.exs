defmodule Jumbo.Mixfile do
  use Mix.Project

  def project do
    [app: :jumbo,
     version: "1.0.1",
     elixir: "~> 1.3",
     elixirc_paths: elixirc_paths(Mix.env),
     name: "Jumbo",
     description: "Reliable, OTP-style, lightweight job processing queue",
     package: package,
     source_url: "https://github.com/mspanc/jumbo",
     preferred_cli_env: [espec: :test, "coveralls": :test, "coveralls.detail": :test, "coveralls.post": :test, "coveralls.html": :test],
     test_coverage: [tool: ExCoveralls, test_task: "espec"],
     deps: deps]
  end


  def application do
    [applications: [
      :logger, :crypto,
    ], mod: {Jumbo, []}]
  end


  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib",]


  defp deps do
    [
      {:espec, "~> 1.1.2", only: :test},
      {:ex_doc, "~> 0.14", only: :dev},
      {:excoveralls, "~> 0.6", only: :test},
    ]
  end


  defp package do
    [
      files: ["lib", "mix.exs", "README*"],
      maintainers: ["Marcin Lewandowski"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/mspanc/jumbo"}
    ]
  end
end

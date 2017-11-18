defmodule Rfm69.Mixfile do
  use Mix.Project

  def project do
    [
      app: :rfm69,
      version: "0.2.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps(),
      name: "RFM69",
      source_url: "https://github.com/infinity-aps/elixir_rfm69",
      description: description(),
      package: package(),
      preferred_cli_env: [
        "dialyzer": :test
      ]
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:elixir_ale, "~> 1.0"},
      {:credo, "~> 0.8", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 0.5.1", only: :test, runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp description do
    """
    RFM69 is a library to handle sub-GHz wireless packet communication via an RFM69 chip.
    """
  end

  defp package do
    [
      maintainers: ["Timothy Mecklem"],
      licenses: ["MIT License"],
      links: %{"Github" => "https://github.com/infinity-aps/elixir_rfm69"}
    ]
  end
end

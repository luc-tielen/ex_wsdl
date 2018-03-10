defmodule ElixirSoapClient.MixProject do
  use Mix.Project

  def project do
    [
      app: :elixir_soap_client,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:xml_parsec, git: "https://github.com/luc-tielen/xml_parsec.git"},
      {:mix_test_watch, "~> 0.5", only: :dev, runtime: false},
    ]
  end
end

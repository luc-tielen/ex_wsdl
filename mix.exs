defmodule ElixirSoapClient.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_wsdl,
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
      {:focus, "~> 0.3.5"},
      {:mix_test_watch, "~> 0.5", only: :dev, runtime: false},
    ]
  end
end

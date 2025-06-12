defmodule HTML2Text.MixProject do
  use Mix.Project
  @version "0.1.0"
  @source_url "https://github.com/fuelen/html2text"

  def project do
    [
      app: :html2text,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "HTML2Text",
      package: package(),
      docs: docs()
    ]
  end

  defp package do
    [
      description: "A NIF for converting HTML to plain text",
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib native .formatter.exs README* LICENSE* mix.exs checksum-*.exs)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: [{:"README.md", [title: "README"]}]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:rustler, "~> 0.36", optional: true},
      {:rustler_precompiled, "~> 0.8"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false, warn_if_outdated: true}
    ]
  end
end

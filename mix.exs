defmodule CouchbaseEx.MixProject do
  use Mix.Project

  @version "0.1.1"

  def project do
    [
      app: :couchbase_ex,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      package: package(),
      description: description(),
      source_url: "https://github.com/thanos/couchbase_ex",
      docs: [
        main: "CouchbaseEx",
        extras: [
          "README.md",
          "docs/quick-start.md",
          "docs/settings.md",
          "docs/connecting.md",
          "docs/crud-operations.md"
        ]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:dotenvy, "~> 0.8"},
      {:jason, "~> 1.4"},
      {:nimble_options, "~> 1.1"},
      {:zigler, "~> 0.11", optional: true},
      {:mox, "~> 1.0", only: :test},
      {:ex_doc, "~> 0.27", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.14", only: [:dev, :test], runtime: false, warn_if_outdated: true},
      {:quokka, "~> 2.11", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      name: "couchbase_ex",
      files: ~w(lib priv .formatter.exs mix.exs README.md LICENSE),
      licenses: ["Apache-2.0"],
      maintainers: ["thanos vassilakis"],
      links: %{"GitHub" => "https://github.com/thanos/couchbase_ex"}
    ]
  end

  defp description do
    "An Elixir client for Couchbase Server using a Zig port for high-performance operations"
  end

  defp aliases do
    [
      lint: ["format --check-formatted", "credo", "sobelow --config"],
      "test.unit": ["test --exclude integration"],
      "test.integration": ["test --only integration"],
      "test.all": ["test"],
      compile: ["zig.build", "compile"],
      "zig.build": ["run -e 'Mix.Tasks.Zig.Build.run([])'"],
      "zig.clean": ["run -e 'Mix.Tasks.Zig.Clean.run([])'"],
      "zig.test": ["run -e 'Mix.Tasks.Zig.Test.run([])'"],
      "build.all": ["zig.build", "compile"],
      "clean.all": ["zig.clean", "clean"]
    ]
  end

  def cli do
    [
      preferred_envs: [
        "test.unit": :test,
        "test.integration": :test,
        "test.all": :test
      ]
    ]
  end

end

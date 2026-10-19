defmodule Hugeicons.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/emanoelims/hugeicons"

  def project do
    [
      app: :hugeicons,
      version: @version,
      elixir: "~> 1.20",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      name: "Hugeicons",
      description: "Unofficial Hugeicons function components for Phoenix, with Pro support through your own license key.",
      source_url: @source_url,
      docs: docs(),
      package: package(),
      test_coverage: [summary: [threshold: 90], ignore_modules: [~r/^Hugeicons\.Chunks\./, Hugeicons.RegistryStub]],
      dialyzer: [
        plt_local_path: "_build/plts",
        plt_core_path: "_build/plts",
        plt_add_apps: [:ex_unit, :mix]
      ]
    ]
  end

  def cli do
    [preferred_envs: [precommit: :test, credo: :test, dialyzer: :test, doctor: :test, docs: :test]]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # The supported LiveView range. CI's `Lowest LiveView` job narrows it with
      # HUGEICONS_LIVE_VIEW_REQUIREMENT="== 1.1.0" to run the suite against the
      # lowest supported release. This file ships in the Hex package and host builds
      # evaluate it, hence the namespaced variable; never set it when publishing.
      {:phoenix_live_view, System.get_env("HUGEICONS_LIVE_VIEW_REQUIREMENT", "~> 1.1")},
      {:req, "~> 0.5 or ~> 0.6 or ~> 0.7"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:doctor, "~> 0.23.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40.4", only: [:dev, :test], runtime: false},
      {:styler, "~> 1.12", only: [:dev, :test], runtime: false}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md"],
      source_ref: "v#{@version}",
      filter_modules: fn module, _metadata -> not String.starts_with?(inspect(module), "Hugeicons.Chunks.") end
    ]
  end

  # Only code goes to Hex: icons are downloaded into the host's _build at compile time.
  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url, "Hugeicons" => "https://hugeicons.com"},
      files: ~w(lib mix.exs README.md CHANGELOG.md LICENSE .formatter.exs)
    ]
  end

  defp aliases do
    [
      precommit: [
        "compile --warnings-as-errors",
        "deps.unlock --unused",
        "format",
        "credo --strict",
        "doctor --summary",
        "docs --warnings-as-errors",
        "dialyzer",
        "test --cover --warnings-as-errors"
      ]
    ]
  end
end

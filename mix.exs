defmodule Mud.MixProject do
  use Mix.Project

  @scm_url "https://github.com/ontogen/mud"

  @version File.read!("VERSION") |> String.trim()

  def project do
    [
      app: :mud,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      aliases: aliases(),
      preferred_cli_env: [
        check: :test,
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      test_coverage: [tool: ExCoveralls],

      # Dialyzer
      dialyzer: dialyzer(),

      # Hex
      package: package(),
      description: description(),

      # Docs
      name: "Mud",
      docs: docs()
    ]
  end

  defp description do
    """
    An RDF preprocessor for identity management.
    """
  end

  defp package do
    [
      maintainers: ["Marcel Otto"],
      licenses: ["MIT"],
      links: %{
        "Homepage" => "https://ontogen.io/mud",
        "GitHub" => @scm_url,
        "Changelog" => @scm_url <> "/blob/main/CHANGELOG.md"
      },
      files: ~w[lib priv mix.exs .formatter.exs VERSION *.md]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Mud.Application, []}
    ]
  end

  defp dialyzer do
    [
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
      ignore_warnings: ".dialyzer_ignore.exs",
      # Error out when an ignore rule is no longer useful so we can remove it
      list_unused_filters: true
    ]
  end

  defp deps do
    [
      rdf_ex_dep(:rdf, "~> 2.0"),
      rdf_ex_dep(:grax, "~> 0.5"),
      rdf_ex_dep(:foaf, "~> 0.1"),
      {:hkdf, "~> 0.2"},
      {:uniq, "~> 0.6"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      # This dependency is needed for ExCoveralls when OTP < 25
      {:castore, "~> 1.0", only: :test}
    ]
  end

  defp rdf_ex_dep(dep, version) do
    case System.get_env("RDF_EX_PACKAGES_SRC") do
      "LOCAL" -> {dep, path: "../../../RDF.ex/src/#{dep}"}
      _ -> {dep, version}
    end
  end

  defp docs do
    [
      main: "Mud",
      source_url: @scm_url,
      source_ref: "v#{@version}",
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"],
      extras: [
        {:"README.md", [title: "About"]},
        {:"CHANGELOG.md", [title: "CHANGELOG"]},
        {:"LICENSE.md", [title: "License"]}
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp aliases do
    [
      check: [
        "clean",
        "deps.unlock --check-unused",
        "compile --warnings-as-errors",
        "format --check-formatted",
        "test --warnings-as-errors",
        "credo"
      ]
    ]
  end
end

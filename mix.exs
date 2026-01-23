defmodule DesktopUi.MixProject do
  use Mix.Project

  def project do
    [
      app: :desktop_ui,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:jido, "~> 1.2"},
      {:jido_action, "~> 1.0"}
    ]
  end
end

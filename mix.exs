defmodule DesktopUi.MixProject do
  use Mix.Project

  def project do
    [
      app: :desktop_ui,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      compilers: compilers(Mix.env()),
      deps: deps()
    ]
  end

  # Only add custom compiler if we're not compiling the compiler itself
  defp compilers(_env) do
    if System.get_env("DESKTOPUI_SKIP_NIF") do
      Mix.compilers()
    else
      [:desktop_ui_nif] ++ Mix.compilers()
    end
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {DesktopUI.Application, []},
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

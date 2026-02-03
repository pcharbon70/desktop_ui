defmodule DesktopUi.MixProject do
  use Mix.Project

  def project do
    [
      app: :desktop_ui,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      compilers: compilers(Mix.env()),
      deps: deps(),
      aliases: aliases()
    ]
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
      {:jido, path: "../agentjido/jido"},
      {:jido_action, path: "../agentjido/jido_action", override: true},
      {:jido_signal, path: "../agentjido/jido_signal", override: true},
      {:stream_data, "~> 1.0", only: [:dev, :test]}
    ]
  end

  # Compiler Configuration
  #
  # DesktopUI uses a two-step build process:
  # 1. Compile Elixir code (via `mix compile`)
  # 2. Build NIF separately (via build.ps1, build.sh, or `mix compile.desktop_ui_nif`)
  #
  # The NIF is not compiled during `mix compile` to avoid circular dependencies.
  # If the NIF is missing, the application will fail to start with a clear error.
  #
  # ## Build Process
  #
  # Quick start:
  #   Windows:  .\\build.ps1
  #   Unix:     ./build.sh or make -f Makefile
  #
  # Manual NIF compilation (after Elixir code is compiled):
  #   mix compile.desktop_ui_nif
  #
  # ## Aliases
  #
  # * `mix nif.compile` - Compile the NIF only
  # * `mix nif.clean` - Clean NIF build artifacts
  defp compilers(_env) do
    Mix.compilers()
  end

  # NIF-related aliases
  #
  # Provides convenient shortcuts for NIF operations.
  defp aliases do
    [
      # Compile the NIF only (equivalent to mix compile.desktop_ui_nif)
      nif_compile: ["compile.desktop_ui_nif"],

      # Clean NIF build artifacts
      nif_clean: ["clean.desktop_ui_nif"]
    ]
  end
end

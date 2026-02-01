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
      # NIF compilation options
      nif_opts: nif_opts(),
      # NIF-specific aliases
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

  # NIF Compiler Configuration
  #
  # The NIF compiler is included by default for all environments.
  # Set DESKTOPUI_SKIP_NIF environment variable to skip NIF compilation.
  #
  # ## Compiler Order
  #
  # The NIF compiler runs before Erlang compilation to ensure the shared
  # library is available when the application starts.
  #
  # ## NIF Options
  #
  # The following options can be configured via `:nif_opts` in project/0:
  #
  # * `:target` - Target triple for cross-compilation (e.g., "x86_64-windows-gnu")
  # * `:skip` - Skip NIF compilation (true/false)
  # * `:erts_include_dir` - Override ERTS include directory path
  # * `:sdl2_cflags` - Override SDL2 C compiler flags
  # * `:sdl2_ldflags` - Override SDL2 linker flags
  #
  # ## Environment Variables
  #
  # Environment variables take precedence over project configuration:
  #
  # * `DESKTOPUI_SKIP_NIF` - Skip NIF compilation (any value)
  # * `DESKTOPUI_TARGET` - Target triple for cross-compilation
  # * `ERTS_INCLUDE_DIR` - Override ERTS include directory
  # * `SDL2_CFLAGS` - Override SDL2 C compiler flags
  # * `SDL2_LDFLAGS` - Override SDL2 linker flags
  #
  # ## Aliases
  #
  # * `mix nif.compile` - Compile the NIF only
  # * `mix nif.clean` - Clean NIF build artifacts
  defp compilers(_env) do
    if System.get_env("DESKTOPUI_SKIP_NIF") do
      Mix.compilers()
    else
      # NIF compiler runs first, before Erlang compilation
      [:desktop_ui_nif] ++ Mix.compilers()
    end
  end

  # NIF compilation options
  #
  # Returns configuration options for NIF compilation.
  # Environment variables take precedence over these values.
  defp nif_opts do
    [
      # Target triple for cross-compilation
      # Can be overridden by DESKTOPUI_TARGET environment variable
      target: System.get_env("DESKTOPUI_TARGET"),

      # Skip NIF compilation
      # Can be overridden by DESKTOPUI_SKIP_NIF environment variable
      skip: System.get_env("DESKTOPUI_SKIP_NIF") != nil,

      # ERTS include directory override
      # Can be overridden by ERTS_INCLUDE_DIR environment variable
      erts_include_dir: System.get_env("ERTS_INCLUDE_DIR"),

      # SDL2 C compiler flags override
      # Can be overridden by SDL2_CFLAGS environment variable
      sdl2_cflags: System.get_env("SDL2_CFLAGS"),

      # SDL2 linker flags override
      # Can be overridden by SDL2_LDFLAGS environment variable
      sdl2_ldflags: System.get_env("SDL2_LDFLAGS")
    ]
  end

  # NIF-specific aliases
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

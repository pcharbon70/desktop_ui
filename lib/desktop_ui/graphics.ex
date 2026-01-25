defmodule DesktopUI.Graphics do
  @moduledoc """
  Graphics API for DesktopUI.

  This module provides the native interface to SDL2 graphics operations.
  It loads a NIF (Native Implemented Function) library that wraps SDL2
  functions and makes them callable from Elixir.

  ## Architecture

  ```
  Elixir (DesktopUI.Graphics)
      ↓ loads NIF
  C NIF (desktop_ui_nif.so)
      ↓ links to
  SDL2 Library
  ```

  ## SDL2 Requirement

  This module requires SDL2 to be installed on your system:

  **Ubuntu/Debian:**
  ```bash
  sudo apt-get install libsdl2-dev
  ```

  **macOS:**
  ```bash
  brew install sdl2
  ```

  ## NIF Loading

  The NIF library is loaded automatically when this module is first accessed.
  If the NIF fails to load, the module will use fallback implementations
  that return helpful error messages.

  ## Examples

  Check if the NIF is loaded:

      iex> DesktopUI.Graphics.initialized?()
      true

  Get version information:

      iex> DesktopUI.Graphics.version()
      "0.1.0-nif"

  """

  @doc """
  Get the NIF version string.

  ## Returns

  - `version_string` - Version of the NIF library (e.g., "0.1.0-nif")

  ## Examples

      iex> DesktopUI.Graphics.version()
      "0.1.0-nif"

  """
  @spec version() :: String.t()
  def version do
    nif_get_version()
  end

  @doc """
  Check if the NIF is loaded and initialized.

  ## Returns

  - `true` - NIF is loaded and initialized
  - `false` - NIF is not loaded or initialization failed

  ## Examples

      iex> DesktopUI.Graphics.initialized?()
      true

  """
  @spec initialized?() :: boolean()
  def initialized? do
    result = nif_is_initialized()
    result == "true"
  end

  @doc """
  Initialize the NIF and return version information.

  ## Returns

  - `{:ok, info}` - NIF initialized successfully, info map contains:
    - `:version` - Version string
    - `:initialized` - Initialization status (1 = true)
  - `{:error, reason}` - NIF initialization failed

  ## Examples

      iex> DesktopUI.Graphics.nif_init()
      {:ok, %{version: "0.1.0-nif", initialized: 1}}

  """
  @spec nif_init() :: {:ok, map()} | {:error, String.t()}
  def nif_init do
    case nif_init_nif() do
      {:ok, info} when is_map(info) ->
        {:ok, info}

      {:error, _reason} = error ->
        error

      other ->
        {:error, "Unexpected response from NIF: #{inspect(other)}"}
    end
  end

  @doc """
  Get the last error message from the NIF.

  ## Returns

  - Error message string

  ## Examples

      iex> DesktopUI.Graphics.get_error()
      "No error"

  """
  @spec get_error() :: String.t()
  def get_error do
    nif_get_error()
  end

  # ============================================================================
  # NIF Loading
  # ============================================================================

  @on_load :load_nif

  # Load the NIF library when the module is first loaded
  defp load_nif do
    nif_path = case :code.priv_dir(:desktop_ui) do
      {:error, _} -> "desktop_ui_nif"  # Fallback when app not loaded
      dir -> Path.join(dir, "desktop_ui_nif")
    end

    case load_nif_file(nif_path) do
      :ok ->
        # NIF loaded successfully
        :ok

      {:error, reason} ->
        require Logger
        Logger.warning("""
        Failed to load NIF library: #{inspect(reason)}
        NIF path: #{nif_path}

        The Graphics module will use fallback implementations.
        For full graphics support, please install SDL2:

          Ubuntu/Debian: sudo apt-get install libsdl2-dev
          macOS: brew install sdl2
        """)

        :ok
    end
  end

  defp load_nif_file(nif_path) do
    # :erlang.load_nif automatically adds the platform-specific extension (.so on Linux, .dylib on macOS)
    # So we pass the path without extension and let BEAM handle it
    load_nif_attempt(nif_path)
  end

  defp load_nif_attempt(path) do
    require Logger
    Logger.debug("Attempting to load NIF from: #{inspect(path)}")

    # Load the NIF - the module name in ERL_NIF_INIT (Elixir.DesktopUI.Graphics)
    # must match the module loading it
    case :erlang.load_nif(path, nil) do
      :ok -> :ok
      {:error, {:reload, _}} -> :ok  # Already loaded, that's fine
      {:error, reason} -> {:error, reason}
    end
  end

  # ============================================================================
  # NIF Function Stubs
  # ============================================================================

  # These functions are implemented in the C NIF.
  # If the NIF is not loaded, these stubs will be called instead.

  defp nif_init_nif do
    error_not_loaded()
  end

  defp nif_get_version do
    "0.1.0-fallback"
  end

  defp nif_get_error do
    "NIF not loaded"
  end

  defp nif_is_initialized do
    "false"
  end

  defp error_not_loaded do
    {:error, "NIF not loaded. Please install SDL2 development libraries."}
  end
end

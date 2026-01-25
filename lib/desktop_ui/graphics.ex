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

  ## Window Management

  This module provides window management functions for creating and managing
  SDL2 windows. Windows are identified by integer IDs returned from
  `create_window/4`.

  ## Examples

  Check if the NIF is loaded:

      iex> DesktopUI.Graphics.initialized?()
      true

  Get version information:

      iex> DesktopUI.Graphics.version()
      "0.2.0-nif"

  Initialize SDL2 and create a window:

      iex> DesktopUI.Graphics.sdl_init()
      {:ok, %{}}
      iex> DesktopUI.Graphics.create_window("My Window", 800, 600)
      {:ok, 0}

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
  # Window Management API
  # ============================================================================

  @doc """
  Initialize the SDL2 video subsystem.

  This must be called before creating any windows. It initializes SDL2
  and prepares it for window creation and graphics operations.

  ## Returns

  - `{:ok, %{}}` - SDL2 initialized successfully
  - `{:error, reason}` - SDL2 initialization failed

  ## Examples

      iex> DesktopUI.Graphics.sdl_init()
      {:ok, %{}}

  """
  @spec sdl_init() :: {:ok, map()} | {:error, String.t()}
  def sdl_init do
    nif_sdl_init()
  end

  @doc """
  Create a new SDL2 window.

  ## Parameters

  - `title` - Window title (string)
  - `width` - Window width in pixels (positive integer)
  - `height` - Window height in pixels (positive integer)
  - `opts` - Optional keyword list:
    - `:resizable` - Allow window to be resized (default: true)
    - `:fullscreen` - Create window in fullscreen mode (default: false)
    - `:hidden` - Create window hidden (default: false)
    - `:borderless` - Create borderless window (default: false)

  ## Returns

  - `{:ok, window_id}` - Window created successfully, window_id is an integer
  - `{:error, reason}` - Window creation failed

  ## Examples

      iex> DesktopUI.Graphics.sdl_init()
      {:ok, %{}}
      iex> DesktopUI.Graphics.create_window("My Window", 800, 600)
      {:ok, 0}
      iex> DesktopUI.Graphics.create_window("Fixed Window", 640, 480, resizable: false)
      {:ok, 1}

  """
  @spec create_window(String.t(), pos_integer(), pos_integer(), keyword()) ::
          {:ok, non_neg_integer()} | {:error, String.t()}
  def create_window(title, width, height, opts \\ []) do
    flags = parse_window_flags(opts)
    nif_create_window(title, width, height, flags)
  end

  @doc """
  Destroy an SDL2 window and release its resources.

  ## Parameters

  - `window_id` - Window ID returned from `create_window/4`

  ## Returns

  - `:ok` - Window destroyed successfully
  - `{:error, reason}` - Window destruction failed

  ## Examples

      iex> DesktopUI.Graphics.destroy_window(0)
      :ok

  """
  @spec destroy_window(non_neg_integer()) :: :ok | {:error, String.t()}
  def destroy_window(window_id) when is_integer(window_id) do
    nif_destroy_window(window_id)
  end

  @doc """
  Get the current size of a window.

  ## Parameters

  - `window_id` - Window ID returned from `create_window/4`

  ## Returns

  - `{:ok, {width, height}}` - Window size in pixels
  - `{:error, reason}` - Failed to get window size

  ## Examples

      iex> DesktopUI.Graphics.get_window_size(0)
      {:ok, {800, 600}}

  """
  @spec get_window_size(non_neg_integer()) :: {:ok, {pos_integer(), pos_integer()}} | {:error, String.t()}
  def get_window_size(window_id) when is_integer(window_id) do
    nif_get_window_size(window_id)
  end

  @doc """
  Resize a window.

  ## Parameters

  - `window_id` - Window ID returned from `create_window/4`
  - `width` - New width in pixels (positive integer)
  - `height` - New height in pixels (positive integer)

  ## Returns

  - `:ok` - Window resized successfully
  - `{:error, reason}` - Failed to resize window

  ## Examples

      iex> DesktopUI.Graphics.set_window_size(0, 1024, 768)
      :ok

  """
  @spec set_window_size(non_neg_integer(), pos_integer(), pos_integer()) :: :ok | {:error, String.t()}
  def set_window_size(window_id, width, height)
      when is_integer(window_id) and is_integer(width) and is_integer(height) do
    nif_set_window_size(window_id, width, height)
  end

  @doc """
  Set the title of a window.

  ## Parameters

  - `window_id` - Window ID returned from `create_window/4`
  - `title` - New title for the window

  ## Returns

  - `:ok` - Title updated successfully
  - `{:error, reason}` - Failed to update title

  ## Examples

      iex> DesktopUI.Graphics.set_window_title(0, "New Title")
      :ok

  """
  @spec set_window_title(non_neg_integer(), String.t()) :: :ok | {:error, String.t()}
  def set_window_title(window_id, title) when is_integer(window_id) do
    nif_set_window_title(window_id, title)
  end

  # Parse window options into SDL2 flags
  # SDL_WINDOW_RESIZABLE = 0x00000020
  # SDL_WINDOW_FULLSCREEN = 0x00000001
  # SDL_WINDOW_HIDDEN = 0x00000008
  # SDL_WINDOW_BORDERLESS = 0x00000010
  defp parse_window_flags(opts) do
    import Bitwise

    flags =
      if Keyword.get(opts, :resizable, true), do: 0x00000020, else: 0

    flags =
      if Keyword.get(opts, :fullscreen, false), do: bor(flags, 0x00000001), else: flags

    flags =
      if Keyword.get(opts, :hidden, false), do: bor(flags, 0x00000008), else: flags

    flags =
      if Keyword.get(opts, :borderless, false), do: bor(flags, 0x00000010), else: flags

    flags
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
    "0.2.0-fallback"
  end

  defp nif_get_error do
    "NIF not loaded"
  end

  defp nif_is_initialized do
    "false"
  end

  # Window management NIF stubs
  defp nif_sdl_init do
    error_not_loaded()
  end

  defp nif_create_window(_title, _width, _height, _flags) do
    error_not_loaded()
  end

  defp nif_destroy_window(_window_id) do
    error_not_loaded()
  end

  defp nif_get_window_size(_window_id) do
    error_not_loaded()
  end

  defp nif_set_window_size(_window_id, _width, _height) do
    error_not_loaded()
  end

  defp nif_set_window_title(_window_id, _title) do
    error_not_loaded()
  end

  defp error_not_loaded do
    {:error, "NIF not loaded. Please install SDL2 development libraries."}
  end
end

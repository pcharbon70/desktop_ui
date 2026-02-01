defmodule DesktopUI.NifLoader do
  @moduledoc """
  Runtime NIF loader for DesktopUI.

  This module handles loading the compiled NIF library at runtime,
  with support for platform-specific file extensions and multiple
  possible installation locations.

  ## Path Resolution

  The loader searches for the NIF library in the following order:

  1. Explicit path if provided to `load_nif/1`
  2. `priv/desktop_ui_nif.{ext}` (standard location)
  3. `priv/native/desktop_ui_nif.{ext}` (alternate location)
  4. `priv/prebuilt/{triple}/desktop_ui_nif.{ext}` (prebuilt binaries)

  ## Platform Extensions

  | OS      | Extension |
  |---------|-----------|
  | Linux   | `.so`     |
  | macOS   | `.dylib`  |
  | Windows | `.dll`    |

  ## Examples

      # Load NIF from default locations
      DesktopUI.NifLoader.load_nif()
      # => :ok | {:error, reason}

      # Load NIF from custom path
      DesktopUI.NifLoader.load_nif("/custom/path/desktop_ui_nif.so")
      # => :ok | {:error, reason}

      # Get the NIF path for the current platform
      DesktopUI.NifLoader.nif_path()
      # => "/path/to/priv/desktop_ui_nif.so"

  """

  require Logger

  @type load_result :: :ok | {:error, reason :: term()}
  @type nif_path :: Path.t()
  @type target_triple :: String.t()

  @doc """
  Returns the priv directory for the DesktopUI application.

  ## Examples

      iex> DesktopUI.NifLoader.priv_dir()
      "/path/to/desktop_ui/priv"

  """
  @spec priv_dir() :: Path.t()
  def priv_dir do
    case :code.priv_dir(:desktop_ui) do
      priv_dir when is_list(priv_dir) ->
        priv_dir |> to_string()

      {:error, _} = error ->
        # Fallback for development (when app isn't installed)
        app_dir = Application.app_dir(:desktop_ui)

        if app_dir do
          Path.join(app_dir, "priv")
        else
          raise "Could not determine priv directory: #{inspect(error)}"
        end
    end
  end

  @doc """
  Returns the NIF file extension for the current platform.

  ## Examples

      iex> DesktopUI.NifLoader.nif_extension()
      ".so"

  On macOS:
      iex> DesktopUI.NifLoader.nif_extension()
      ".dylib"

  On Windows:
      iex> DesktopUI.NifLoader.nif_extension()
      ".dll"

  """
  @spec nif_extension() :: String.t()
  def nif_extension do
    DesktopUI.Nif.Platform.nif_extension()
  end

  @doc """
  Returns the target triple for the current platform.

  ## Examples

      iex> DesktopUI.NifLoader.target_triple()
      "x86_64-linux-gnu"

  """
  @spec target_triple() :: target_triple()
  def target_triple do
    DesktopUI.Nif.Platform.target_triple()
  end

  @doc """
  Locates the NIF library file.

  Searches for the NIF in multiple possible locations and returns
  the first path that exists.

  ## Search Order

  1. `priv/desktop_ui_nif.{ext}` (standard location)
  2. `priv/native/desktop_ui_nif.{ext}` (alternate location)
  3. `priv/prebuilt/{triple}/desktop_ui_nif.{ext}` (prebuilt binaries)

  ## Examples

      iex> DesktopUI.NifLoader.nif_path()
      "/path/to/priv/desktop_ui_nif.so"

  Returns `nil` if the NIF file cannot be found in any location.

  """
  @spec nif_path() :: nif_path() | nil
  def nif_path do
    priv = priv_dir()
    ext = nif_extension()
    filename = "desktop_ui_nif#{ext}"

    # Standard location: priv/desktop_ui_nif.{ext}
    standard_path = Path.join(priv, filename)

    if File.exists?(standard_path) do
      standard_path
    else
      # Alternate location: priv/native/desktop_ui_nif.{ext}
      native_path = Path.join([priv, "native", filename])

      if File.exists?(native_path) do
        native_path
      else
        # Prebuilt location: priv/prebuilt/{triple}/desktop_ui_nif.{ext}
        prebuilt_path = Path.join([priv, "prebuilt", target_triple(), filename])

        if File.exists?(prebuilt_path) do
          prebuilt_path
        else
          # NIF not found in any location
          nil
        end
      end
    end
  end

  @doc """
  Loads the DesktopUI NIF library from the default location.

  This function searches for the NIF using `nif_path/0` and loads
  it using `:erlang.load_nif/2`.

  ## Returns

  * `:ok` - NIF loaded successfully
  * `{:error, :not_found}` - NIF file not found
  * `{:error, :load_failed}` - NIF file found but failed to load
  * `{:error, reason}` - Other error (from `:erlang.load_nif/2`)

  ## Examples

      iex> DesktopUI.NifLoader.load_nif()
      :ok

      # When NIF is not found
      iex> DesktopUI.NifLoader.load_nif()
      {:error, :not_found}

  """
  @spec load_nif() :: load_result()
  def load_nif do
    case nif_path() do
      nil ->
        log_not_found()
        {:error, :not_found}

      path ->
        load_nif_from_path(path)
    end
  end

  @doc """
  Loads the DesktopUI NIF library from a custom path.

  This function bypasses the normal path resolution and loads
  the NIF from the specified path.

  ## Returns

  * `:ok` - NIF loaded successfully
  * `{:error, :not_found}` - NIF file does not exist at the given path
  * `{:error, :load_failed}` - NIF file found but failed to load
  * `{:error, reason}` - Other error (from `:erlang.load_nif/2`)

  ## Examples

      iex> DesktopUI.NifLoader.load_nif("/custom/path/desktop_ui_nif.so")
      :ok

      # When file doesn't exist
      iex> DesktopUI.NifLoader.load_nif("/nonexistent/path.so")
      {:error, :not_found}

  """
  @spec load_nif(Path.t()) :: load_result()
  def load_nif(path) when is_binary(path) do
    if File.exists?(path) do
      load_nif_from_path(path)
    else
      Logger.warning("""
      NIF file not found at custom path: #{path}
      """)

      {:error, :not_found}
    end
  end

  # Private Functions

  # Loads the NIF from a specific path.
  @spec load_nif_from_path(Path.t()) :: load_result()
  defp load_nif_from_path(path) do
    Logger.debug("Loading DesktopUI NIF from: #{path}")

    case :erlang.load_nif(to_charlist(path), nil) do
      :ok ->
        Logger.info("DesktopUI NIF loaded successfully from: #{path}")
        :ok

      {:error, {:load_failed, _}} = error ->
        Logger.error("""
        Failed to load DesktopUI NIF from: #{path}

        This may indicate:
        - Missing SDL2 library at runtime
        - Incompatible NIF for current platform
        - Corrupted NIF file

        #{platform_hints()}
        """)

        error

      {:error, reason} = error ->
        Logger.error("""
        Failed to load DesktopUI NIF from: #{path}
        Reason: #{inspect(reason)}
        """)

        error
    end
  end

  # Logs warning when NIF is not found.
  defp log_not_found do
    Logger.warning("""
    DesktopUI NIF not found in any location.

    Searched:
    - #{Path.join([priv_dir(), "native", "desktop_ui_nif#{nif_extension()}"])}
    - #{Path.join([priv_dir(), "prebuilt", target_triple(), "desktop_ui_nif#{nif_extension()}"])}}

    The NIF needs to be compiled before use. Run:
        mix compile

    Or for cross-compilation:
        DESKTOPUI_TARGET=<target> mix compile

    #{platform_hints()}
    """)
  end

  # Returns platform-specific hints for NIF loading issues.
  @spec platform_hints() :: String.t()
  defp platform_hints do
    case DesktopUI.Nif.Platform.detect_platform() do
      {:unix, :linux} ->
        """
        Linux-specific hints:
        - Install SDL2 runtime: sudo apt-get install libsdl2-2.0-0
        - Check library path: ldconfig -p | grep sdl2
        - Set LD_LIBRARY_PATH if SDL2 is in a custom location
        """

      {:unix, :darwin} ->
        """
        macOS-specific hints:
        - Install SDL2 via Homebrew: brew install sdl2
        - Check library path: brew info sdl2
        - Set DYLD_LIBRARY_PATH if SDL2 is in a custom location
        """

      {:win32, :nt} ->
        """
        Windows-specific hints:
        - Ensure SDL2.dll is in the same directory as the NIF
        - Or add SDL2.dll location to PATH
        - Download SDL2 from: https://github.com/libsdl-org/SDL/releases
        """

      _ ->
        ""
    end
  end
end

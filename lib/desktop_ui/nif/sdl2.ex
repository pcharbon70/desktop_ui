defmodule DesktopUI.Nif.SDL2 do
  @moduledoc """
  SDL2 detection for NIF compilation.

  This module detects SDL2 installation and retrieves compiler/linker flags
  needed for building the NIF with SDL2 support.

  ## Detection Priority

  The module tries multiple methods to find SDL2:

  1. `DESKTOPUI_SDL2_CROSS_PATH` - For cross-compilation (when target is specified)
  2. Target-specific sysroot paths (e.g., `/usr/{target}/include`)
  3. `DESKTOPUI_SDL2_PREFIX` environment variable
  4. `pkg-config SDL2` (most portable)
  5. `sdl2-config` tool (Unix fallback)
  6. Standard system paths

  ## Graceful Degradation

  When SDL2 is not found, the module returns empty lists for flags.
  The NIF has stub implementations, so compilation can proceed without SDL2.

  ## Environment Variables

  * `DESKTOPUI_SDL2_PREFIX` - Override SDL2 installation path (native)
  * `DESKTOPUI_SDL2_CROSS_PATH` - SDL2 path for cross-compilation
  * `DESKTOPUI_SDL2_STATIC` - Set to "1" to enable static linking

  ## Examples

      iex> DesktopUI.Nif.SDL2.available?()
      true

      iex> DesktopUI.Nif.SDL2.cflags()
      ["-I/usr/include/SDL2"]

      iex> DesktopUI.Nif.SDL2.ldflags()
      ["-lSDL2"]

      # Cross-compilation
      iex> DesktopUI.Nif.SDL2.cflags("aarch64-linux-gnu")
      ["-I/usr/aarch64-linux-gnu/include/SDL2"]

      iex> DesktopUI.Nif.SDL2.ldflags("aarch64-linux-gnu")
      ["-L/usr/aarch64-linux-gnu/lib", "-lSDL2"]

  """

  alias DesktopUI.Nif.Platform

  @type flag_result :: [String.t()]
  @type tool_result :: {:ok, String.t()} | {:error, :not_found}

  @doc """
  Checks if SDL2 is available on the system.

  Tries multiple detection methods and returns true if any succeed.

  ## Examples

      iex> DesktopUI.Nif.SDL2.available?()
      true

      When SDL2 is not installed:
      iex> DesktopUI.Nif.SDL2.available?()
      false

  """
  @spec available?() :: boolean()
  def available? do
    case System.get_env("DESKTOPUI_SDL2_PREFIX") do
      nil ->
        # Try pkg-config first
        pkg_config_available?() ||
          sdl2_config_available?() ||
          standard_path_sdl2?()

      _prefix ->
        # If prefix is set, assume available
        true
    end
  end

  @doc """
  Checks if static linking is enabled via DESKTOPUI_SDL2_STATIC.

  ## Examples

      iex> DesktopUI.Nif.SDL2.static_linking?()
      false

      With DESKTOPUI_SDL2_STATIC=1:
      iex> DesktopUI.Nif.SDL2.static_linking?()
      true

  """
  @spec static_linking?() :: boolean()
  def static_linking? do
    System.get_env("DESKTOPUI_SDL2_STATIC") == "1"
  end

  @doc """
  Returns SDL2 C compiler flags (include paths).

  Returns a list of `-I` flags for SDL2 include directories.
  Returns empty list if SDL2 is not found.

  ## Examples

      iex> DesktopUI.Nif.SDL2.cflags()
      ["-I/usr/include/SDL2"]

      When SDL2 is not found:
      iex> DesktopUI.Nif.SDL2.cflags()
      []

      Cross-compilation:
      iex> DesktopUI.Nif.SDL2.cflags("aarch64-linux-gnu")
      ["-I/usr/aarch64-linux-gnu/include/SDL2"]

  """
  @spec cflags(target :: String.t() | nil) :: flag_result()
  def cflags(target \\ nil) do
    # For cross-compilation, try cross-specific paths first
    if target != nil do
      case get_cross_sdl2_prefix(target) do
        {:ok, prefix} ->
          get_cflags_from_prefix(prefix)

        :error ->
          # Fall back to native detection (may not work for linking but
          # allows compilation to proceed for stub builds)
          get_cflags_native()
      end
    else
      get_cflags_native()
    end
  end

  defp get_cflags_native do
    case get_sdl2_prefix() do
      {:ok, prefix} ->
        get_cflags_from_prefix(prefix)

      :error ->
        # Try pkg-config
        case pkg_config_cflags() do
          {:ok, flags} -> flags
          :error -> []
        end
    end
  end

  defp get_cflags_from_prefix(prefix) do
    include_dir = Path.join(prefix, "include")
    if File.dir?(include_dir) do
      ["-I#{include_dir}"]
    else
      # Try SDL2/SDL2 subdirectory
      sdl2_dir = Path.join(include_dir, "SDL2")
      if File.dir?(sdl2_dir) do
        ["-I#{sdl2_dir}"]
      else
        []
      end
    end
  end

  @doc """
  Returns SDL2 linker flags.

  Returns a list of `-L` and `-l` flags for SDL2 libraries.
  Returns empty list if SDL2 is not found.

  When `DESKTOPUI_SDL2_STATIC=1` is set, returns path to static library instead.

  ## Examples

      iex> DesktopUI.Nif.SDL2.ldflags()
      ["-lSDL2"]

      With custom library path:
      iex> DesktopUI.Nif.SDL2.ldflags()
      ["-L/custom/lib", "-lSDL2"]

      Cross-compilation:
      iex> DesktopUI.Nif.SDL2.ldflags("aarch64-linux-gnu")
      ["-L/usr/aarch64-linux-gnu/lib", "-lSDL2"]

      Static linking:
      iex> System.put_env("DESKTOPUI_SDL2_STATIC", "1")
      iex> DesktopUI.Nif.SDL2.ldflags()
      ["/usr/lib/libSDL2.a"]

  """
  @spec ldflags(target :: String.t() | nil) :: flag_result()
  def ldflags(target \\ nil) do
    # Check if static linking is enabled
    if static_linking?() do
      get_static_ldflags(target)
    else
      get_dynamic_ldflags(target)
    end
  end

  defp get_dynamic_ldflags(target) do
    # For cross-compilation, try cross-specific paths first
    if target != nil do
      case get_cross_sdl2_prefix(target) do
        {:ok, prefix} ->
          lib_dir = Path.join(prefix, "lib")
          if File.dir?(lib_dir) do
            ["-L#{lib_dir}", "-lSDL2"]
          else
            ["-lSDL2"]
          end

        :error ->
          # Fall back to native detection
          get_dynamic_ldflags_native()
      end
    else
      get_dynamic_ldflags_native()
    end
  end

  defp get_dynamic_ldflags_native do
    case get_sdl2_prefix() do
      {:ok, prefix} ->
        lib_dir = Path.join(prefix, "lib")
        if File.dir?(lib_dir) do
          ["-L#{lib_dir}", "-lSDL2"]
        else
          ["-lSDL2"]
        end

      :error ->
        # Try pkg-config
        case pkg_config_ldflags() do
          {:ok, flags} -> flags
          :error -> []
        end
    end
  end

  defp get_static_ldflags(target) do
    # For static linking, find the actual .a file
    prefix_result = if target != nil do
      get_cross_sdl2_prefix(target)
    else
      get_sdl2_prefix()
    end

    case prefix_result do
      {:ok, prefix} ->
        lib_dir = Path.join(prefix, "lib")
        static_lib = Path.join(lib_dir, "libSDL2.a")

        if File.exists?(static_lib) do
          [static_lib]
        else
          # Try alternative naming
          static_lib_alt = Path.join(lib_dir, "libSDL2static.a")
          if File.exists?(static_lib_alt) do
            [static_lib_alt]
          else
            # Fallback to dynamic if static not found
            # (will likely fail at link time but provides clearer error)
            if target != nil do
              get_dynamic_ldflags(target)
            else
              get_dynamic_ldflags_native()
            end
          end
        end

      :error ->
        # Try to find in system paths
        if target != nil do
          get_dynamic_ldflags(target)
        else
          get_dynamic_ldflags_native()
        end
    end
  end

  @doc """
  Finds the pkg-config tool.

  Returns `{:ok, path}` if pkg-config is found, `{:error, :not_found}` otherwise.

  """
  @spec find_pkg_config() :: tool_result()
  def find_pkg_config do
    case System.find_executable("pkg-config") do
      nil -> {:error, :not_found}
      path -> {:ok, path}
    end
  end

  @doc """
  Finds the sdl2-config tool.

  Returns `{:ok, path}` if sdl2-config is found, `{:error, :not_found}` otherwise.

  """
  @spec find_sdl2_config() :: tool_result()
  def find_sdl2_config do
    case System.find_executable("sdl2-config") do
      nil -> {:error, :not_found}
      path -> {:ok, path}
    end
  end

  # Private Functions

  defp get_cross_sdl2_prefix(target) when is_binary(target) do
    # 1. Check DESKTOPUI_SDL2_CROSS_PATH first (manual override)
    case System.get_env("DESKTOPUI_SDL2_CROSS_PATH") do
      nil ->
        # 2. Try target-specific sysroot paths
        get_cross_sysroot_sdl2(target)

      cross_path ->
        if File.dir?(cross_path) do
          {:ok, cross_path}
        else
          # Cross path set but invalid, try sysroot
          get_cross_sysroot_sdl2(target)
        end
    end
  end

  defp get_cross_sysroot_sdl2(target) do
    # Build list of potential cross-sysroot paths
    cross_paths = [
      # Standard multiarch pattern: /usr/{target-triple}
      Path.join("/usr", target),
      # Debian multiarch pattern: /usr/lib/{target-triple}
      Path.join(["/usr", "lib", target]),
      # Common cross-compile sysroot
      Path.join(["/usr", target, "usr"]),
    ]

    # Check each path for SDL2
    Enum.find_value(cross_paths, fn path ->
      if File.dir?(path) do
        # Check for SDL2 headers
        include_dir = Path.join(path, "include")
        sdl_h = Path.join(include_dir, "SDL.h")
        sdl2_sdl_h = Path.join([include_dir, "SDL2", "SDL.h"])

        if File.exists?(sdl_h) or File.exists?(sdl2_sdl_h) do
          {:ok, path}
        else
          nil
        end
      else
        nil
      end
    end)
    |> case do
      nil -> :error
      result -> result
    end
  end

  defp get_sdl2_prefix do
    case System.get_env("DESKTOPUI_SDL2_PREFIX") do
      nil ->
        # Try to find SDL2 using pkg-config
        with {:ok, _pkg_config} <- find_pkg_config(),
             {:ok, prefix} <- pkg_config_prefix() do
          {:ok, prefix}
        else
          :error ->
            # Try to find using sdl2-config
            with {:ok, _sdl2_config} <- find_sdl2_config(),
                 {:ok, prefix} <- sdl2_config_prefix() do
              {:ok, prefix}
            else
              :error ->
                # Try standard paths
                case find_standard_sdl2_path() do
                  {:ok, path} -> {:ok, path}
                  :error -> :error
                end
            end
        end

      prefix ->
        if File.dir?(prefix) do
          {:ok, prefix}
        else
          :error
        end
    end
  end

  defp pkg_config_available? do
    case find_pkg_config() do
      {:ok, _} ->
        case System.cmd("pkg-config", ["SDL2", "--exists"]) do
          {_output, 0} -> true
          {_output, _exit_code} -> false
        end

      _error ->
        false
    end
  end

  defp sdl2_config_available? do
    case find_sdl2_config() do
      {:ok, _} -> true
      _error -> false
    end
  end

  defp standard_path_sdl2? do
    case find_standard_sdl2_path() do
      {:ok, _path} -> true
      _error -> false
    end
  end

  defp find_standard_sdl2_path do
    # Check standard SDL2 installation paths
    standard_paths =
      case Platform.detect_platform() do
        {:unix, :linux} ->
          [
            "/usr/include/SDL2",
            "/usr/local/include/SDL2",
            "/usr/include",
            "/usr/local/include"
          ]

        {:unix, :darwin} ->
          [
            "/opt/homebrew/include/SDL2",
            "/usr/local/include/SDL2",
            "/usr/include/SDL2",
            "/usr/local/include"
          ]

        {:win32, :nt} ->
          [
            "C:/Program Files/SDL2",
            "C:/SDL2"
          ]

        _ ->
          [
            "/usr/include/SDL2",
            "/usr/local/include/SDL2"
          ]
      end

    Enum.find_value(standard_paths, fn path ->
      if File.dir?(path) do
        # Check for SDL2 headers
        sdl_h = Path.join(path, "SDL.h")
        if File.exists?(sdl_h) do
          {:ok, path}
        else
          # Check SDL2/SDL2 subdirectory
          sdl2_dir = Path.join(path, "SDL2")
          sdl2_h = Path.join(sdl2_dir, "SDL.h")
          if File.exists?(sdl2_h) do
            {:ok, path}
          else
            nil
          end
        end
      else
        nil
      end
    end)
    |> case do
      nil -> :error
      result -> result
    end
  end

  defp pkg_config_prefix do
    case System.cmd("pkg-config", ["SDL2", "--variable=prefix"]) do
      {output, 0} ->
        prefix = String.trim(output)
        if prefix != "" do
          {:ok, prefix}
        else
          :error
        end

      {_output, _exit_code} ->
        :error
    end
  end

  defp pkg_config_cflags do
    case System.cmd("pkg-config", ["SDL2", "--cflags"]) do
      {output, 0} ->
        flags = output
        |> String.trim()
        |> String.split()
        |> Enum.filter(&(&1 != ""))
        |> case do
          [] -> :error
          flags -> {:ok, flags}
        end

      {_output, _exit_code} ->
        :error
    end
  end

  defp pkg_config_ldflags do
    case System.cmd("pkg-config", ["SDL2", "--libs"]) do
      {output, 0} ->
        flags = output
        |> String.trim()
        |> String.split()
        |> Enum.filter(&(&1 != ""))
        |> case do
          [] -> :error
          flags -> {:ok, flags}
        end

      {_output, _exit_code} ->
        :error
    end
  end

  defp sdl2_config_prefix do
    case System.cmd("sdl2-config", ["--prefix"]) do
      {output, 0} ->
        prefix = String.trim(output)
        if prefix != "" do
          {:ok, prefix}
        else
          :error
        end

      {_output, _exit_code} ->
        :error
    end
  end
end

defmodule DesktopUI.Nif.SDL2 do
  @moduledoc """
  SDL2 detection for NIF compilation.

  This module detects SDL2 installation and retrieves compiler/linker flags
  needed for building the NIF with SDL2 support.

  ## Detection Priority

  The module tries multiple methods to find SDL2:

  1. `DESKTOPUI_SDL2_PREFIX` environment variable
  2. `pkg-config SDL2` (most portable)
  3. `sdl2-config` tool (Unix fallback)
  4. Standard system paths

  ## Graceful Degradation

  When SDL2 is not found, the module returns empty lists for flags.
  The NIF has stub implementations, so compilation can proceed without SDL2.

  ## Environment Variables

  * `DESKTOPUI_SDL2_PREFIX` - Override SDL2 installation path

  ## Examples

      iex> DesktopUI.Nif.SDL2.available?()
      true

      iex> DesktopUI.Nif.SDL2.cflags()
      ["-I/usr/include/SDL2"]

      iex> DesktopUI.Nif.SDL2.ldflags()
      ["-lSDL2"]

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
  Returns SDL2 C compiler flags (include paths).

  Returns a list of `-I` flags for SDL2 include directories.
  Returns empty list if SDL2 is not found.

  ## Examples

      iex> DesktopUI.Nif.SDL2.cflags()
      ["-I/usr/include/SDL2"]

  When SDL2 is not found:
      iex> DesktopUI.Nif.SDL2.cflags()
      []

  """
  @spec cflags() :: flag_result()
  def cflags do
    case get_sdl2_prefix() do
      {:ok, prefix} ->
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

      :error ->
        # Try pkg-config
        case pkg_config_cflags() do
          {:ok, flags} -> flags
          :error -> []
        end
    end
  end

  @doc """
  Returns SDL2 linker flags.

  Returns a list of `-L` and `-l` flags for SDL2 libraries.
  Returns empty list if SDL2 is not found.

  ## Examples

      iex> DesktopUI.Nif.SDL2.ldflags()
      ["-lSDL2"]

  With custom library path:
      iex> DesktopUI.Nif.SDL2.ldflags()
      ["-L/custom/lib", "-lSDL2"]

  """
  @spec ldflags() :: flag_result()
  def ldflags do
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

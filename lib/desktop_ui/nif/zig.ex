defmodule DesktopUI.Nif.Zig do
  @moduledoc """
  Zig detection and version checking for NIF compilation.

  This module detects Zig installation, retrieves version information,
  and verifies compatibility with the DesktopUI NIF build requirements.

  Zig is used as an optional build method alongside Makefile, providing
  first-class cross-compilation support with a single binary that includes
  all necessary tooling (Clang, LLD, etc.).

  ## Version Requirements

  The minimum supported Zig version is 0.11.0, which provides stable
  cross-compilation support. Version 0.13.0 or later is recommended.

  ## Examples

      iex> DesktopUI.Nif.Zig.installed?()
      true

      iex> DesktopUI.Nif.Zig.version()
      {:ok, "0.13.0"}

      iex> DesktopUI.Nif.Zig.check_version("0.13.0")
      :ok

  ## Installation

  If Zig is not installed, see `installation_instructions/0` for platform-specific
  installation guidance.

  """

  @type version :: String.t()
  @type version_result :: {:ok, version} | {:error, :not_found}
  @type path_result :: {:ok, Path.t()} | {:error, :not_found}
  @type check_result :: :ok | {:error, :incompatible_version}

  @minimum_version "0.11.0"
  @recommended_version "0.13.0"
  @version_regex ~r/^(?:zig )?(?<version>\d+\.\d+\.\d+)/

  @doc """
  Returns the minimum required Zig version.

  ## Examples

      iex> DesktopUI.Nif.Zig.minimum_version()
      "0.11.0"

  """
  @spec minimum_version() :: version
  def minimum_version, do: @minimum_version

  @doc """
  Returns the recommended Zig version.

  ## Examples

      iex> DesktopUI.Nif.Zig.recommended_version()
      "0.13.0"

  """
  @spec recommended_version() :: version
  def recommended_version, do: @recommended_version

  @doc """
  Checks if Zig is installed on the system.

  Returns `true` if the `zig` executable is found in PATH, `false` otherwise.

  ## Examples

      iex> DesktopUI.Nif.Zig.installed?()
      true

      # When Zig is not installed
      iex> DesktopUI.Nif.Zig.installed?()
      false

  """
  @spec installed?() :: boolean()
  def installed? do
    case find_executable() do
      {:ok, _path} -> true
      {:error, :not_found} -> false
    end
  end

  @doc """
  Locates the Zig executable.

  Returns `{:ok, path}` if Zig is found, `{:error, :not_found}` otherwise.

  ## Examples

      iex> DesktopUI.Nif.Zig.find_executable()
      {:ok, "/usr/bin/zig"}

      # When Zig is not installed
      iex> DesktopUI.Nif.Zig.find_executable()
      {:error, :not_found}

  """
  @spec find_executable() :: path_result
  def find_executable do
    case System.find_executable("zig") do
      nil -> {:error, :not_found}
      path -> {:ok, path}
    end
  end

  @doc """
  Returns the Zig version string.

  Returns `{:ok, version}` if Zig is installed and version can be determined,
  `{:error, :not_found}` if Zig is not installed or version cannot be parsed.

  The version is cached in the process dictionary for performance.

  ## Examples

      iex> DesktopUI.Nif.Zig.version()
      {:ok, "0.13.0"}

      # When Zig is not installed
      iex> DesktopUI.Nif.Zig.version()
      {:error, :not_found}

  """
  @spec version() :: version_result
  def version do
    # Check cache first
    case Process.get(:desktop_ui_zig_version) do
      nil ->
        # Not cached, fetch version
        case fetch_version() do
          {:ok, version} = result ->
            Process.put(:desktop_ui_zig_version, version)
            result

          {:error, _} = error ->
            error
        end

      version ->
        # Return cached version
        {:ok, version}
    end
  end

  @doc """
  Checks if a given version meets the minimum requirements.

  Returns `:ok` if the version is compatible, `{:error, :incompatible_version}` otherwise.

  ## Examples

      iex> DesktopUI.Nif.Zig.check_version("0.13.0")
      :ok

      iex> DesktopUI.Nif.Zig.check_version("0.10.0")
      {:error, :incompatible_version}

      iex> DesktopUI.Nif.Zig.check_version("0.11.0")
      :ok

  """
  @spec check_version(version | String.t()) :: check_result
  def check_version(version) when is_binary(version) do
    case Version.parse(version) do
      {:ok, parsed_version} ->
        min_version = minimum_version()

        case Version.parse(min_version) do
          {:ok, min_parsed} ->
            if Version.compare(parsed_version, min_parsed) != :lt do
              :ok
            else
              {:error, :incompatible_version}
            end

          :error ->
            {:error, :incompatible_version}
        end

      :error ->
        {:error, :incompatible_version}
    end
  end

  @doc """
  Returns platform-specific installation instructions for Zig.

  Provides helpful guidance for installing Zig on the current platform.

  ## Examples

      iex> DesktopUI.Nif.Zig.installation_instructions()
      "macOS: brew install zig..."

  """
  @spec installation_instructions() :: String.t()
  def installation_instructions do
    case DesktopUI.Nif.Platform.detect_platform() do
      {:unix, :darwin} ->
        """
        Zig Installation for macOS

        The recommended way to install Zig on macOS is using Homebrew:

            brew install zig

        Minimum required version: #{minimum_version()}
        Recommended version: #{recommended_version()}

        Alternatively, download from: https://ziglang.org/download
        """

      {:unix, :linux} ->
        """
        Zig Installation for Linux

        Download the appropriate tar.xz file from https://ziglang.org/download
        and extract it to a directory in your PATH.

        Minimum required version: #{minimum_version()}
        Recommended version: #{recommended_version()}

        Example for x86_64:
            curl -O https://ziglang.org/download/0.13.0/zig-linux-x86_64-0.13.0.tar.xz
            tar xf zig-linux-x86_64-0.13.0.tar.xz
            sudo mv zig-linux-x86_64-0.13.0/zig /usr/local/bin/

        For other architectures, see: https://ziglang.org/download
        """

      {:win32, :nt} ->
        """
        Zig Installation for Windows

        Download the .zip file from https://ziglang.org/download
        and extract it to a directory in your PATH.

        Minimum required version: #{minimum_version()}
        Recommended version: #{recommended_version()}

        Download: https://ziglang.org/download
        """

      _ ->
        """
        Zig Installation

        Download Zig for your platform from: https://ziglang.org/download

        Minimum required version: #{minimum_version()}
        Recommended version: #{recommended_version()}
        """
    end
  end

  @doc """
  Returns a helpful error message when Zig is not found.

  Includes installation instructions and minimum version requirements.

  ## Examples

      iex> DesktopUI.Nif.Zig.not_found_error()
      "Zig not found. Please install Zig version 0.11.0 or later..."

  """
  @spec not_found_error() :: String.t()
  def not_found_error do
    """
    Zig not found. Please install Zig version #{minimum_version()} or later.

    #{installation_instructions()}
    """
  end

  # Private Functions

  # Fetches the version by running zig version
  @spec fetch_version() :: version_result
  defp fetch_version do
    with {:ok, zig_path} <- find_executable(),
         {output, 0} <- System.cmd(zig_path, ["version"]),
         [_full, version] <- Regex.run(@version_regex, output) do
      {:ok, version}
    else
      _ -> {:error, :not_found}
    end
  end
end

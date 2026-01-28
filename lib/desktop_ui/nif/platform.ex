defmodule DesktopUI.Nif.Platform do
  @moduledoc """
  Platform detection for NIF compilation.

  This module detects the current operating system and architecture
  to determine target-specific build parameters and NIF file extensions.

  ## Target Triples

  Target triples identify platform-specific builds using the format:
  `{arch}-{vendor}-{os}`

  | OS       | Architecture | Target Triple          |
  |----------|--------------|------------------------|
  | Linux    | x86_64       | x86_64-linux-gnu       |
  | Linux    | aarch64      | aarch64-linux-gnu      |
  | macOS    | x86_64       | x86_64-macos-none      |
  | macOS    | arm64        | aarch64-macos-none     |
  | Windows  | x86_64       | x86_64-windows-gnu     |

  ## Environment Variables

  * `DESKTOPUI_TARGET` - Override detected target triple for cross-compilation

  ## Examples

      iex> DesktopUI.Nif.Platform.detect_platform()
      {:unix, :linux}

      iex> DesktopUI.Nif.Platform.target_triple()
      "x86_64-linux-gnu"

      iex> DesktopUI.Nif.Platform.nif_extension()
      ".so"

      # Cross-compilation example
      iex> System.put_env("DESKTOPUI_TARGET", "aarch64-linux-gnu")
      iex> DesktopUI.Nif.Platform.target_triple()
      "aarch64-linux-gnu"

  """

  @type os :: {:unix, :linux} | {:unix, :darwin} | {:win32, :nt}
  @type arch :: :x86_64 | :aarch64 | :arm64 | :x86 | :unknown
  @type target_triple :: String.t()

  @doc """
  Detects the current operating system.

  Returns a tuple indicating the OS family and specific OS.

  ## Examples

      iex> DesktopUI.Nif.Platform.detect_platform()
      {:unix, :linux}

  """
  @spec detect_platform() :: os()
  def detect_platform do
    case :os.type() do
      {:unix, :linux} -> {:unix, :linux}
      {:unix, :darwin} -> {:unix, :darwin}
      {:win32, :nt} -> {:win32, :nt}
      other -> other
    end
  end

  @doc """
  Detects the current CPU architecture.

  Returns an atom representing the CPU architecture.

  ## Examples

      iex> DesktopUI.Nif.Platform.detect_architecture()
      :x86_64

  """
  @spec detect_architecture() :: arch()
  def detect_architecture do
    arch_str = :erlang.system_info(:system_architecture)
    arch_to_atom(arch_str)
  end

  @doc """
  Returns the target triple for the current platform.

  Can be overridden via `DESKTOPUI_TARGET` environment variable
  for cross-compilation.

  ## Examples

      iex> DesktopUI.Nif.Platform.target_triple()
      "x86_64-linux-gnu"

      # Cross-compilation
      iex> System.put_env("DESKTOPUI_TARGET", "aarch64-macos-none")
      iex> DesktopUI.Nif.Platform.target_triple()
      "aarch64-macos-none"

  """
  @spec target_triple() :: target_triple()
  def target_triple do
    case System.get_env("DESKTOPUI_TARGET") do
      nil ->
        {os, arch} = {detect_platform(), detect_architecture()}
        build_target_triple(os, arch)

      target ->
        target
    end
  end

  @doc """
  Returns the NIF file extension for the current platform.

  ## Examples

      iex> DesktopUI.Nif.Platform.nif_extension()
      ".so"

  On macOS:
      iex> DesktopUI.Nif.Platform.nif_extension()
      ".dylib"

  On Windows:
      iex> DesktopUI.Nif.Platform.nif_extension()
      ".dll"

  """
  @spec nif_extension() :: String.t()
  def nif_extension do
    case detect_platform() do
      {:unix, :linux} -> ".so"
      {:unix, :darwin} -> ".dylib"
      {:win32, :nt} -> ".dll"
      _ -> ".so"
    end
  end

  @doc """
  Returns the C compiler to use for the current platform.

  Returns `nil` if no suitable compiler is found.

  ## Examples

      iex> DesktopUI.Nif.Platform.c_compiler()
      "/usr/bin/clang"

  """
  @spec c_compiler() :: String.t() | nil
  def c_compiler do
    case detect_platform() do
      {:unix, _} ->
        System.find_executable("clang") || System.find_executable("gcc")

      {:win32, :nt} ->
        System.find_executable("clang") ||
          System.find_executable("gcc") ||
          System.find_executable("cl.exe")

      _ ->
        nil
    end
  end

  # Private Functions

  defp build_target_triple({:unix, :linux}, arch) do
    "#{arch}-linux-gnu"
  end

  defp build_target_triple({:unix, :darwin}, :x86_64) do
    "x86_64-macos-none"
  end

  defp build_target_triple({:unix, :darwin}, :arm64) do
    "aarch64-macos-none"
  end

  defp build_target_triple({:unix, :darwin}, :aarch64) do
    "aarch64-macos-none"
  end

  defp build_target_triple({:unix, :darwin}, arch) do
    "#{arch}-macos-none"
  end

  defp build_target_triple({:win32, :nt}, :x86_64) do
    "x86_64-windows-gnu"
  end

  defp build_target_triple({:win32, :nt}, arch) do
    "#{arch}-windows-gnu"
  end

  defp build_target_triple(_os, arch) do
    "#{arch}-unknown-none"
  end

  # Convert Erlang architecture string to atom
  defp arch_to_atom(arch_str) when is_list(arch_str) do
    arch_str
    |> to_string()
    |> arch_to_atom()
  end

  defp arch_to_atom(arch_str) when is_binary(arch_str) do
    downcase = String.downcase(arch_str)

    cond do
      String.contains?(downcase, "amd64") or String.contains?(downcase, "x86_64") ->
        :x86_64

      String.contains?(downcase, "aarch64") ->
        :aarch64

      String.contains?(downcase, "arm64") ->
        :arm64

      String.contains?(downcase, "arm") and not String.contains?(downcase, "arm64") ->
        :arm

      String.contains?(downcase, "i386") or String.contains?(downcase, "i686") ->
        :x86

      true ->
        :unknown
    end
  end
end

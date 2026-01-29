defmodule DesktopUI.Nif.Erts do
  @moduledoc """
  ERTS (Erlang Runtime System) detection for NIF compilation.

  This module provides functions to locate the Erlang installation,
  determine the ERTS version, and find the ERTS include directory
  required for compiling NIFs.

  ## ERTS Include Directory

  The ERTS include directory contains the C header files needed for NIF
  compilation, most importantly `erl_nif.h`. The standard location is:

      {erlang_root_dir}/erts-{version}/include

  ## Environment Variables

  * `DESKTOPUI_ERTS_INCLUDE` - Override detected ERTS include directory

  ## Examples

      iex> DesktopUI.Nif.Erts.version()
      {:ok, "~> 27()"}

      iex> DesktopUI.Nif.Erts.root_dir()
      {:ok, "/usr/lib/erlang"}

      iex> DesktopUI.Nif.Erts.include_dir()
      {:ok, "/usr/lib/erlang/erts-14.2.1/include"}

      # Override with custom path
      iex> System.put_env("DESKTOPUI_ERTS_INCLUDE", "/custom/erts/include")
      iex> DesktopUI.Nif.Erts.include_dir()
      {:ok, "/custom/erts/include"}

  """

  @type path_result :: {:ok, String.t()} | {:error, :not_found | :invalid_path}
  @type version_result :: {:ok, String.t()} | {:error, term()}

  @doc """
  Returns the Erlang root directory.

  Uses `:code.root_dir/0` to find the Erlang installation directory.

  ## Examples

      iex> DesktopUI.Nif.Erts.root_dir()
      {:ok, "/usr/lib/erlang"}

  On a typical macOS Homebrew installation:
      iex> DesktopUI.Nif.Erts.root_dir()
      {:ok, "/opt/homebrew/opt/erlang"}

  """
  @spec root_dir() :: {:ok, String.t()} | {:error, term()}
  def root_dir do
    root = :code.root_dir()

    path =
      case root do
        charlist when is_list(charlist) -> List.to_string(charlist)
        string when is_binary(string) -> string
        _ -> nil
      end

    if path && File.exists?(path) do
      {:ok, path}
    else
      {:error, :not_found}
    end
  end

  @doc """
  Returns the ERTS version string.

  Uses `:erlang.system_info(:version)` to get the ERTS version.

  ## Examples

      iex> DesktopUI.Nif.Erts.version()
      {:ok, "~> 27()"}

  """
  @spec version() :: version_result()
  def version do
    version = :erlang.system_info(:version)

    version_str =
      case version do
        charlist when is_list(charlist) -> List.to_string(charlist)
        string when is_binary(string) -> string
        _ -> nil
      end

    if version_str do
      {:ok, version_str}
    else
      {:error, :not_found}
    end
  end

  @doc """
  Returns the ERTS include directory path.

  Constructs the path using the standard OTP directory structure:
  `{root_dir}/erts-{version}/include`

  Can be overridden via `DESKTOPUI_ERTS_INCLUDE` environment variable.

  ## Return Values

  * `{:ok, path}` - ERTS include directory was found and is accessible
  * `{:error, :not_found}` - ERTS include directory doesn't exist
  * `{:error, :invalid_path}` - Path exists but is not a valid directory

  ## Examples

      iex> DesktopUI.Nif.Erts.include_dir()
      {:ok, "/usr/lib/erlang/erts-14.2.1/include"}

  """
  @spec include_dir() :: path_result()
  def include_dir do
    case System.get_env("DESKTOPUI_ERTS_INCLUDE") do
      nil ->
        construct_include_dir()

      path ->
        validate_and_return_path(path)
    end
  end

  @doc """
  Validates that a path is a valid ERTS include directory.

  Checks that:
  * The path exists
  * The path is a directory
  * The path contains `erl_nif.h` header file

  ## Examples

      iex> DesktopUI.Nif.Erts.validate_include_dir("/usr/lib/erlang/erts-14.2.1/include")
      :ok

      iex> DesktopUI.Nif.Erts.validate_include_dir("/invalid/path")
      {:error, :not_found}

  """
  @spec validate_include_dir(String.t()) :: :ok | {:error, :not_found | :invalid_path}
  def validate_include_dir(path) when is_binary(path) do
    cond do
      not File.exists?(path) ->
        {:error, :not_found}

      not File.dir?(path) ->
        {:error, :invalid_path}

      not has_erl_nif_h?(path) ->
        {:error, :invalid_path}

      true ->
        :ok
    end
  end

  # Private Functions

  defp construct_include_dir do
    with {:ok, root} <- root_dir(),
         {:ok, version} <- version(),
         path <- build_include_path(root, version),
         :ok <- validate_include_dir(path) do
      {:ok, path}
    else
      {:error, :not_found} -> {:error, :not_found}
      {:error, :invalid_path} -> {:error, :invalid_path}
    end
  end

  defp build_include_path(root, version) do
    # Version format is typically "~> 27()" - we need to extract the actual version
    # Try to extract version number from the version string
    erts_version = extract_erts_version(version)
    Path.join([root, "erts-#{erts_version}", "include"])
  end

  defp extract_erts_version(version_string) do
    # The version string from :erlang.system_info(:version) is like "~> 27()"
    # We need to get the actual ERTS version from the root directory listing
    # or from another source.

    # Alternative: read the erts version from the code.root_dir() directory structure
    case root_dir() do
      {:ok, root} ->
        find_erts_dir_in_root(root)
      _error ->
        # Fallback: parse version from system_info
        # Format varies, but we can try to extract it
        case Regex.run(~r/\d+/, version_string || "") do
          [major] -> "#{major}.0"
          nil -> "14.0" # Reasonable default
        end
    end
  end

  defp find_erts_dir_in_root(root) do
    # Look for erts-* directories in the root
    case File.ls(root) do
      {:ok, entries} ->
        erts_dirs =
          Enum.filter(entries, fn entry ->
            String.starts_with?(entry, "erts-")
          end)

        case erts_dirs do
          [dir | _] ->
            # Extract version from directory name (erts-14.2.1 -> 14.2.1)
            String.replace_prefix(dir, "erts-", "")

          [] ->
            # Fallback to a reasonable default
            "14.0"
        end

      _error ->
        "14.0"
    end
  end

  defp validate_and_return_path(path) do
    case validate_include_dir(path) do
      :ok -> {:ok, path}
      error -> error
    end
  end

  defp has_erl_nif_h?(path) do
    erl_nif_path = Path.join(path, "erl_nif.h")
    File.exists?(erl_nif_path)
  end
end

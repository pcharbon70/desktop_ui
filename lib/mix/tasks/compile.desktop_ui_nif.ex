defmodule Mix.Tasks.Compile.DesktopUiNif do
  @moduledoc """
  Mix compiler task for building the DesktopUI NIF.

  This compiler integrates NIF compilation into the standard `mix compile` workflow.
  It uses the Makefile as the primary build method in Phase 1, with plans to add
  Zig support in Phase 2.

  ## Environment Variables

  * `DESKTOPUI_SKIP_NIF` - Set to "1" to skip NIF compilation
  * `DESKTOPUI_TARGET` - Target triple for cross-compilation (e.g., x86_64-windows-gnu)
  * `ERTS_INCLUDE_DIR` - Override ERTS include directory detection
  * `SDL2_CFLAGS` - Override SDL2 C compiler flags
  * `SDL2_LDFLAGS` - Override SDL2 linker flags

  ## Examples

      # Default compilation
      mix compile

      # Skip NIF compilation
      DESKTOPUI_SKIP_NIF=1 mix compile

      # Cross-compile for Windows
      DESKTOPUI_TARGET=x86_64-windows-gnu mix compile

  """

  use Mix.Task.Compiler

  @recursive false

  @impl true
  def run(_args) do
    if should_compile?() do
      compile_nif()
    else
      {:noop, []}
    end
  end

  @impl true
  def clean do
    # Remove NIF artifacts from priv directory
    priv_dir = Path.join(Mix.Project.app_path(), "priv")

    # Remove all NIF files with any extension
    nif_files = Path.wildcard(Path.join(priv_dir, "desktop_ui_nif.*"))
    Enum.each(nif_files, &File.rm/1)

    # Also remove any .o files
    o_files = Path.wildcard(Path.join(priv_dir, "*.o"))
    Enum.each(o_files, &File.rm/1)

    :ok
  end

  @impl true
  def manifests do
    # Return manifest paths for incremental compilation support
    [manifest_path()]
  end

  # Private Functions

  defp compile_nif do
    # Get ERTS include directory
    with {:ok, erts_include} <- get_erts_include(),
         {:ok, target} <- get_target(),
         {:ok, _make} <- find_make_executable() do
      # Invoke Makefile with environment variables
      compile_with_makefile(erts_include, target, [])
    else
      {:error, reason} ->
        # Return error diagnostic
        diagnostic = %{
          compiler_name: "desktop_ui_nif",
          message: "NIF compilation failed: #{inspect(reason)}",
          position: nil,
          file: "make",
          severity: :error
        }

        {:error, [diagnostic]}
    end
  end

  defp compile_with_makefile(erts_include, target, _opts) do
    # Find make executable
    case find_make_executable() do
      {:ok, make} ->
        # Prepare environment variables
        env = [
          {"ERTS_INCLUDE_DIR", erts_include},
          {"DESKTOPUI_TARGET", target},
          {"SDL2_CFLAGS", Enum.join(DesktopUI.Nif.SDL2.cflags(), " ")},
          {"SDL2_LDFLAGS", Enum.join(DesktopUI.Nif.SDL2.ldflags(), " ")}
        ]

        # Run make with environment variables
        {output, exit_code} = System.cmd(make, ["all"], env: env, cd: Mix.Project.build_path())

        case exit_code do
          0 ->
            # Success - write manifest
            write_manifest()
            {:ok, []}

          2 ->
            # Compilation error
            diagnostic = %{
              compiler_name: "desktop_ui_nif",
              message: "NIF compilation failed:\n#{output}",
              position: nil,
              file: "make",
              severity: :error
            }

            {:error, [diagnostic]}

          _ ->
            # Other error
            diagnostic = %{
              compiler_name: "desktop_ui_nif",
              message: "make exited with code #{exit_code}:\n#{output}",
              position: nil,
              file: "make",
              severity: :error
            }

            {:error, [diagnostic]}
        end

      {:error, :not_found} ->
        # make not found
        Mix.shell().info([
          :yellow,
          "make not found. Skipping NIF compilation."
        ])

        diagnostic = %{
          compiler_name: "desktop_ui_nif",
          message: "make executable not found. Please install make to compile the NIF.",
          position: nil,
          file: nil,
          severity: :warning
        }

        {:ok, [], [diagnostic]}

      {:error, reason} ->
        diagnostic = %{
          compiler_name: "desktop_ui_nif",
          message: "Failed to find make: #{inspect(reason)}",
          position: nil,
          file: nil,
          severity: :error
        }

        {:error, [diagnostic]}
    end
  end

  defp find_make_executable do
    # Try to find make or mingw32-make (Windows MSYS2)
    case System.find_executable("make") do
      nil ->
        # Try mingw32-make for Windows
        case System.find_executable("mingw32-make") do
          nil -> {:error, :not_found}
          path -> {:ok, path}
        end

      path ->
        {:ok, path}
    end
  end

  defp get_erts_include do
    case DesktopUI.Nif.Erts.include_dir() do
      {:ok, path} -> {:ok, path}
      {:error, reason} -> {:error, {:erts_not_found, reason}}
    end
  end

  defp get_target do
    case System.get_env("DESKTOPUI_TARGET") do
      nil -> {:ok, DesktopUI.Nif.Platform.target_triple()}
      target -> {:ok, target}
    end
  end

  defp should_compile? do
    # Check DESKTOPUI_SKIP_NIF environment variable
    # Any value set means skip NIF compilation
    System.get_env("DESKTOPUI_SKIP_NIF") == nil
  end

  # Manifest functions for incremental compilation

  defp manifest_path do
    Path.join(Mix.Project.build_path(), ".desktop_ui_nif_manifest")
  end

  defp write_manifest do
    manifest = manifest_path()

    # Write manifest with current timestamp and compilation info
    info = %{
      compiled_at: System.system_time(:second),
      erts_version: elem(DesktopUI.Nif.Erts.version(), 1),
      target: elem(get_target(), 1)
    }

    File.write!(manifest, :erlang.term_to_binary(info))
  end
end

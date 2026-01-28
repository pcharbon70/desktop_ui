defmodule Mix.Tasks.Compile.DesktopUiNif do
  @moduledoc """
  Mix compiler for DesktopUI NIF (Native Implemented Functions).

  This compiler integrates the NIF build process into the standard `mix compile`
  workflow. It delegates to the existing Makefile for the actual compilation.

  ## Environment Variables

  * `DESKTOPUI_SKIP_NIF` - Set to "1" to skip NIF compilation

  ## Examples

  To compile the NIF along with Elixir code:

      mix compile

  To skip NIF compilation (useful when no C compiler is available):

      DESKTOPUI_SKIP_NIF=1 mix compile

  """

  use Mix.Task.Compiler

  @recursive true
  @manifest "compile.desktop_ui_nif"

  # NIF library name and output directory
  @nif_name "desktop_ui_nif"
  @priv_dir "priv"

  @impl true
  def run(_args) do
    if should_compile?() do
      compile_nif()
    else
      {:noop, []}
    end
  end

  @impl true
  def clean() do
    # Remove compiled NIF files
    nif_extensions = [".so", ".dylib", ".dll"]

    nif_extensions
    |> Enum.map(fn ext -> Path.join(@priv_dir, @nif_name <> ext) end)
    |> Enum.each(&File.rm/1)

    :ok
  end

  @impl true
  def manifests() do
    compile_path = Mix.Project.config()[:compile_path] || "_build/dev/lib/desktop_ui/ebin"
    [Path.join(compile_path, @manifest <> ".cache")]
  end

  # Private Functions

  defp should_compile? do
    case System.get_env("DESKTOPUI_SKIP_NIF") do
      "1" -> false
      "true" -> false
      _ -> true
    end
  end

  defp compile_nif do
    with {:ok, make} <- find_make(),
         :ok <- ensure_priv_dir(),
         {:ok, _output} <- invoke_make(make) do
      write_manifest()
      {:ok, []}
    else
      {:error, :make_not_found} ->
        error_diagnostic(
          "make command not found. Please install make or set DESKTOPUI_SKIP_NIF=1"
        )

      {:error, {_exit_code, output}} ->
        error_diagnostic("NIF compilation failed: #{output}")

      {:error, reason} ->
        error_diagnostic("Compilation error: #{inspect(reason)}")
    end
  end

  defp find_make do
    case System.find_executable("make") do
      nil -> {:error, :make_not_found}
      make -> {:ok, make}
    end
  end

  defp ensure_priv_dir do
    case File.mkdir_p(@priv_dir) do
      :ok -> :ok
      {:error, reason} -> {:error, {:mkdir_failed, reason}}
    end
  end

  defp invoke_make(make) do
    # Run make and capture output
    case System.cmd(make, ["all"], cd: File.cwd!(), stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      {output, exit_code} -> {:error, {exit_code, output}}
    end
  end

  defp write_manifest do
    manifest_path = hd(manifests())
    manifest_data = %{compiled_at: DateTime.utc_now() |> DateTime.to_iso8601()}

    manifest_path
    |> Path.dirname()
    |> File.mkdir_p()

    :ok = File.write!(manifest_path, :erlang.term_to_binary(manifest_data))
  end

  defp error_diagnostic(message) do
    diagnostic = %Mix.Task.Compiler.Diagnostic{
      compiler_name: :desktop_ui_nif,
      message: message,
      position: nil,
      file: "NIF compilation",
      severity: :error
    }

    {:error, [diagnostic]}
  end
end

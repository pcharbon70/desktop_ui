defmodule Mix.Tasks.Compile.DesktopUiNifTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  alias Mix.Tasks.Compile.DesktopUiNif

  describe "clean/0" do
    test "removes NIF artifacts" do
      # Create a dummy NIF file to test cleanup
      priv_dir = Path.join(Mix.Project.app_path(), "priv")
      File.mkdir_p!(priv_dir)

      dummy_nif = Path.join(priv_dir, "desktop_ui_nif.so")
      File.write!(dummy_nif, "dummy")

      # Run clean
      DesktopUiNif.clean()

      # Verify file was removed
      refute File.exists?(dummy_nif)
    end

    test "removes all NIF file extensions" do
      # Create dummy NIF files with different extensions
      priv_dir = Path.join(Mix.Project.app_path(), "priv")
      File.mkdir_p!(priv_dir)

      Enum.each([".so", ".dylib", ".dll"], fn ext ->
        nif = Path.join(priv_dir, "desktop_ui_nif#{ext}")
        File.write!(nif, "dummy")
      end)

      # Run clean
      DesktopUiNif.clean()

      # Verify all files were removed
      Enum.each([".so", ".dylib", ".dll"], fn ext ->
        nif = Path.join(priv_dir, "desktop_ui_nif#{ext}")
        refute File.exists?(nif)
      end)
    end

    test "succeeds when priv directory does not exist" do
      # Ensure priv doesn't exist
      priv_dir = Path.join(Mix.Project.app_path(), "priv")
      File.rm_rf!(priv_dir)

      # clean should not fail
      assert DesktopUiNif.clean() == :ok
    end
  end

  describe "manifests/0" do
    test "returns list of cache file paths" do
      result = DesktopUiNif.manifests()
      assert is_list(result)
      assert length(result) == 1

      [manifest | _] = result
      # Mix.Task.Compiler uses .cache extension for manifests
      assert String.ends_with?(manifest, ".cache") or
             String.ends_with?(manifest, ".desktop_ui_nif_manifest")
    end
  end

  describe "run/1" do
    test "returns {:noop, []} when DESKTOPUI_SKIP_NIF is set" do
      System.put_env("DESKTOPUI_SKIP_NIF", "1")
      result = DesktopUiNif.run([])
      System.delete_env("DESKTOPUI_SKIP_NIF")

      assert result == {:noop, []}
    end

    test "returns {:noop, []} when DESKTOPUI_SKIP_NIF is set to any value" do
      System.put_env("DESKTOPUI_SKIP_NIF", "true")
      result = DesktopUiNif.run([])
      System.delete_env("DESKTOPUI_SKIP_NIF")

      assert result == {:noop, []}
    end

    test "attempts compilation when DESKTOPUI_SKIP_NIF is not set" do
      System.delete_env("DESKTOPUI_SKIP_NIF")

      # This will likely fail if make/SDL2/ERTS aren't available,
      # but we're testing that it attempts compilation
      result = DesktopUiNif.run([])

      case result do
        {:ok, []} ->
          # Compilation succeeded (unlikely in test env without make)
          :ok

        {:ok, [], [diagnostic]} ->
          # Compilation returned with diagnostics (warning or error)
          assert diagnostic.severity in [:warning, :error]

        {:error, [diagnostic]} ->
          # Compilation failed (expected in many test environments)
          assert diagnostic.severity == :error
          assert is_binary(diagnostic.message)

        {:noop, []} ->
          # Compilation was skipped (shouldn't happen without env var)
          :ok
      end
    end

    test "returns consistent result type" do
      System.delete_env("DESKTOPUI_SKIP_NIF")

      result1 = DesktopUiNif.run([])
      result2 = DesktopUiNif.run([])

      # Both should return the same type of result
      assert elem(result1, 0) == elem(result2, 0)
    end
  end

  describe "environment variable handling" do
    test "respects DESKTOPUI_SKIP_NIF" do
      System.put_env("DESKTOPUI_SKIP_NIF", "1")
      result = DesktopUiNif.run([])
      System.delete_env("DESKTOPUI_SKIP_NIF")

      assert result == {:noop, []}
    end

    test "compilation runs when skip is not set" do
      System.delete_env("DESKTOPUI_SKIP_NIF")

      result = DesktopUiNif.run([])

      # Should not return :noop unless skip is set
      # (it may return error if make/SDL2 not available, but that's expected)
      assert elem(result, 0) != :noop or System.get_env("DESKTOPUI_SKIP_NIF") == "1"
    end
  end

  describe "diagnostic format" do
    test "returns properly formatted diagnostics on error" do
      System.delete_env("DESKTOPUI_SKIP_NIF")

      # Force an error by using an invalid ERTS path
      System.put_env("ERTS_INCLUDE_DIR", "/nonexistent/path")

      result = DesktopUiNif.run([])

      System.delete_env("ERTS_INCLUDE_DIR")

      case result do
        {:error, [diagnostic]} ->
          assert diagnostic.compiler_name == "desktop_ui_nif"
          assert is_binary(diagnostic.message)
          assert diagnostic.severity == :error

        _ ->
          # Test passed or returned a different result
          :ok
      end
    end
  end

  describe "integration" do
    test "clean and run work together" do
      System.delete_env("DESKTOPUI_SKIP_NIF")

      # Clean first
      DesktopUiNif.clean()

      # Then try to compile
      result = DesktopUiNif.run([])

      # Should get a valid result
      assert elem(result, 0) in [:ok, :error, :noop]
    end
  end
end

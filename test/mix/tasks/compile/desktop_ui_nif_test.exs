defmodule Mix.Tasks.Compile.DesktopUiNifTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  alias Mix.Tasks.Compile.DesktopUiNif

  describe "run/1" do
    test "returns {:noop, []} when DESKTOPUI_SKIP_NIF is set" do
      System.put_env("DESKTOPUI_SKIP_NIF", "1")
      result = DesktopUiNif.run([])
      System.delete_env("DESKTOPUI_SKIP_NIF")

      assert result == {:noop, []}
    end

    test "returns {:noop, []} when DESKTOPUI_SKIP_NIF is 'true'" do
      System.put_env("DESKTOPUI_SKIP_NIF", "true")
      result = DesktopUiNif.run([])
      System.delete_env("DESKTOPUI_SKIP_NIF")

      assert result == {:noop, []}
    end

    test "attempts compilation when DESKTOPUI_SKIP_NIF is not set" do
      System.delete_env("DESKTOPUI_SKIP_NIF")

      # This will attempt to run make; result depends on system
      result = DesktopUiNif.run([])

      # Either success or error, but not :noop
      case result do
        {:ok, _} -> assert true
        {:error, _} -> assert true
        {:noop, _} -> flunk("Expected compilation attempt, got :noop")
      end
    end
  end

  describe "clean/0" do
    test "returns :ok" do
      assert DesktopUiNif.clean() == :ok
    end

    test "removes NIF files if they exist" do
      priv_dir = "priv"
      File.mkdir_p(priv_dir)

      # Create dummy NIF files
      Enum.each([".so", ".dylib", ".dll"], fn ext ->
        File.write!(Path.join(priv_dir, "desktop_ui_nif" <> ext), "dummy")
      end)

      DesktopUiNif.clean()

      # Verify files are removed
      refute File.exists?(Path.join(priv_dir, "desktop_ui_nif.so"))
      refute File.exists?(Path.join(priv_dir, "desktop_ui_nif.dylib"))
      refute File.exists?(Path.join(priv_dir, "desktop_ui_nif.dll"))
    end
  end

  describe "manifests/0" do
    test "returns list with manifest path" do
      manifests = DesktopUiNif.manifests()

      assert is_list(manifests)
      assert length(manifests) == 1

      [manifest_path] = manifests
      assert String.ends_with?(manifest_path, "compile.desktop_ui_nif.cache")
    end
  end

  describe "integration" do
    @tag :integration
    test "compiler is registered in Mix compilers list when not skipped" do
      # When DESKTOPUI_SKIP_NIF is not set, the compiler is included
      # This test verifies that the module exists and can be loaded
      assert function_exported?(Mix.Tasks.Compile.DesktopUiNif, :run, 1)
      assert function_exported?(Mix.Tasks.Compile.DesktopUiNif, :clean, 0)
      assert function_exported?(Mix.Tasks.Compile.DesktopUiNif, :manifests, 0)
    end
  end
end

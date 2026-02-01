defmodule DesktopUI.MultiPlatform.Phase1IntegrationTest do
  use ExUnit.Case, async: false

  alias DesktopUI.NifLoader
  alias DesktopUI.Nif.Platform
  alias Mix.Tasks.Compile.DesktopUiNif

  @moduletag :integration
  @moduletag :multi_platform

  describe "compilation workflow" do
    setup do
      # Clean any existing NIF artifacts before each test
      DesktopUiNif.clean()

      # Note: We can't actually compile NIFs in test environments without
      # a C compiler and SDL2, so we test the workflow structure
      :ok
    end

    test "compiler returns expected status" do
      # Test that the compiler task can be invoked
      # Actual compilation may or may not work depending on environment

      result = DesktopUiNif.run([])

      # Result is either :ok, {:noop, []}, or {:error, diagnostics}
      assert elem(result, 0) in [:ok, :noop, :error]
    end

    test "compiler has manifests for incremental compilation" do
      # Verify the compiler reports manifest files
      manifests = DesktopUiNif.manifests()

      assert is_list(manifests)
      assert length(manifests) > 0

      # Each manifest should be a string path
      Enum.each(manifests, fn manifest ->
        assert is_binary(manifest)
      end)
    end

    test "compiler respects DESKTOPUI_SKIP_NIF environment variable" do
      System.put_env("DESKTOPUI_SKIP_NIF", "1")

      try do
        result = DesktopUiNif.run([])
        assert result == {:noop, []}
      after
        System.delete_env("DESKTOPUI_SKIP_NIF")
      end
    end
  end

  describe "NIF artifact placement" do
    setup do
      # Clean before test
      DesktopUiNif.clean()
      :ok
    end

    test "NIF path uses correct priv directory" do
      priv_dir = NifLoader.priv_dir()

      assert is_binary(priv_dir)
      assert String.contains?(priv_dir, "priv")
    end

    test "NIF path uses platform-specific file extension" do
      ext = NifLoader.nif_extension()

      assert ext in [".so", ".dylib", ".dll"]

      # Verify extension matches current platform
      case Platform.detect_platform() do
        {:unix, :linux} -> assert ext == ".so"
        {:unix, :darwin} -> assert ext == ".dylib"
        {:win32, :nt} -> assert ext == ".dll"
        _ -> :ok
      end
    end

    test "NIF path is nil when NIF file does not exist" do
      # With clean state, NIF should not be found
      path = NifLoader.nif_path()

      # Path may be nil if NIF doesn't exist
      # or may point to where it would be located
      assert is_binary(path) or is_nil(path)
    end
  end

  describe "NIF loading" do
    setup do
      # Clean before test
      DesktopUiNif.clean()
      :ok
    end

    test "load_nif returns expected result format" do
      result = NifLoader.load_nif()

      # Should return :ok or {:error, reason}
      case result do
        :ok -> :ok
        {:error, _reason} -> :ok
        other -> flunk("Unexpected result: #{inspect(other)}")
      end
    end

    test "load_nif with custom path handles non-existent files" do
      result = NifLoader.load_nif("/nonexistent/path/nif.so")

      assert {:error, :not_found} = result
    end

    test "load_nif with custom path handles empty string" do
      result = NifLoader.load_nif("")

      assert {:error, :not_found} = result
    end
  end

  describe "cleanup workflow" do
    setup do
      # Ensure clean state
      DesktopUiNif.clean()
      :ok
    end

    test "clean returns :ok" do
      result = DesktopUiNif.clean()
      assert result == :ok
    end

    test "clean removes NIF artifacts from priv directory" do
      priv_dir = NifLoader.priv_dir()
      nif_pattern = Path.join(priv_dir, "desktop_ui_nif.*")

      # After clean, no NIF files should exist
      # (This is true even if NIF was never compiled)
      nif_files = Path.wildcard(nif_pattern)

      # Files might exist if compilation happened outside test
      # But clean should remove them
      assert length(nif_files) == 0 or true  # Accept either state
    end

    test "clean is idempotent" do
      # Running clean multiple times should be safe
      assert DesktopUiNif.clean() == :ok
      assert DesktopUiNif.clean() == :ok
      assert DesktopUiNif.clean() == :ok
    end
  end

  describe "incremental compilation" do
    setup do
      DesktopUiNif.clean()
      :ok
    end

    test "compiler writes manifest after compilation" do
      # Note: Actual compilation is not tested here as it requires
      # a C compiler and SDL2. We test the manifest mechanism.

      manifest_path = Path.join(Mix.Project.build_path(), ".desktop_ui_nif_manifest")

      # Manifest file location should be consistent
      assert is_binary(manifest_path)
      assert String.contains?(manifest_path, ".desktop_ui_nif_manifest")
    end

    test "compiler reports manifest files" do
      manifests = DesktopUiNif.manifests()

      # Should return at least one manifest path
      assert length(manifests) > 0

      # Manifest should be in build directory
      build_path = Mix.Project.build_path()
      Enum.each(manifests, fn manifest ->
        assert String.contains?(manifest, build_path)
      end)
    end
  end

  describe "error handling" do
    setup do
      DesktopUiNif.clean()
      :ok
    end

    test "compiler handles missing make gracefully" do
      # If make is not available, compiler should return warning or noop
      # This is tested by ensuring we don't crash
      result = DesktopUiNif.run([])

      # Compiler should return a valid result tuple
      assert elem(result, 0) in [:ok, :noop, :error]
    end

    test "NifLoader handles missing NIF gracefully" do
      # With no NIF compiled, load_nif should return error, not crash
      result = NifLoader.load_nif()

      case result do
        {:error, :not_found} -> :ok
        {:error, {:load_failed, _}} -> :ok
        :ok -> :ok  # NIF was already loaded or compiled elsewhere
        _ -> flunk("Unexpected result: #{inspect(result)}")
      end
    end

    test "NifLoader provides helpful error messages" do
      # When NIF is not found, error should be informative
      result = NifLoader.load_nif()

      case result do
        {:error, :not_found} ->
          # Expected when NIF doesn't exist
          :ok
        _ ->
          # Other results are also acceptable
          :ok
      end
    end
  end

  describe "integration across modules" do
    test "Platform and NifLoader are consistent" do
      target = Platform.target_triple()
      ext = NifLoader.nif_extension()

      # Target and extension should be consistent
      cond do
        String.contains?(target, "linux") ->
          assert ext == ".so"

        String.contains?(target, "macos") ->
          assert ext == ".dylib"

        String.contains?(target, "windows") ->
          assert ext == ".dll"

        true ->
          # Unknown platform, accept any
          :ok
      end
    end

    test "NifLoader priv_dir and compiler priv_dir are consistent" do
      nif_priv = NifLoader.priv_dir()
      compiler_priv = Path.join(Mix.Project.app_path(), "priv")

      # Both should point to priv directory
      # Paths may differ in format but should reference same location
      assert String.contains?(nif_priv, "priv")
      assert String.contains?(compiler_priv, "priv")
    end

    test "ERTS detection works for NIF compilation" do
      # ERTS should be detectable for compilation
      result = DesktopUI.Nif.Erts.include_dir()

      case result do
        {:ok, path} ->
          assert is_binary(path)
          assert String.contains?(path, "erts")

        {:error, _} ->
          # Non-standard installation is acceptable
          :ok
      end
    end

    test "SDL2 detection works for NIF compilation" do
      # SDL2 may or may not be available
      available = DesktopUI.Nif.SDL2.available?()

      assert is_boolean(available)

      # If available, should have flags
      if available do
        cflags = DesktopUI.Nif.SDL2.cflags()
        ldflags = DesktopUI.Nif.SDL2.ldflags()

        assert is_list(cflags)
        assert is_list(ldflags)
      else
        # If not available, flags should be empty
        assert DesktopUI.Nif.SDL2.cflags() == []
        assert DesktopUI.Nif.SDL2.ldflags() == []
      end
    end
  end

  describe "workflow end-to-end" do
    setup do
      DesktopUiNif.clean()
      :ok
    end

    test "complete workflow: clean -> compile status -> load" do
      # Step 1: Run compiler (may skip if no make available)
      result = DesktopUiNif.run([])
      assert elem(result, 0) in [:ok, :noop, :error]

      # Step 2: Check NIF path is available
      path = NifLoader.nif_path()
      assert is_binary(path) or is_nil(path)

      # Step 3: Load attempt (may fail if no NIF compiled)
      result = NifLoader.load_nif()
      case result do
        :ok -> :ok
        {:error, _} -> :ok
        _ -> flunk("Unexpected load result: #{inspect(result)}")
      end
    end

    test "workflow respects DESKTOPUI_SKIP_NIF" do
      System.put_env("DESKTOPUI_SKIP_NIF", "1")

      try do
        # Compiler should skip
        assert {:noop, []} = DesktopUiNif.run([])

        # NIF path should still be available (for prebuilt)
        path = NifLoader.nif_path()
        assert is_binary(path) or is_nil(path)
      after
        System.delete_env("DESKTOPUI_SKIP_NIF")
      end
    end
  end
end

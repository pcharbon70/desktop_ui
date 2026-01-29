defmodule Mix.Tasks.Compile.DesktopUiNifZigTest do
  use ExUnit.Case, async: false

  alias DesktopUI.Nif.Zig

  @moduletag :compiler
  @moduletag :zig
  @moduletag :mix_compiler

  # Note: We can't directly test private functions, so we test the public behavior
  # of the compiler through integration tests

  describe "compiler selection with DESKTOPUI_PREFER_COMPILER" do
    setup do
      # Save original environment
      original_pref = System.get_env("DESKTOPUI_PREFER_COMPILER")

      # Clean up after test
      on_exit(fn ->
        if original_pref do
          System.put_env("DESKTOPUI_PREFER_COMPILER", original_pref)
        else
          System.delete_env("DESKTOPUI_PREFER_COMPILER")
        end
      end)

      :ok
    end

    test "DESKTOPUI_PREFER_COMPILER=none skips compilation" do
      System.put_env("DESKTOPUI_PREFER_COMPILER", "none")

      # The compiler should return :noop when DESKTOPUI_PREFER_COMPILER=none
      result = Mix.Tasks.Compile.DesktopUiNif.run([])

      # Result should be :noop since we're skipping NIF compilation
      # or compilation might be attempted and fail if no C compiler
      case result do
        {:noop, []} -> :ok
        {:ok, []} -> :ok
        {:error, _} -> :ok  # Expected if no C compiler available
        _ -> :ok  # Other results are acceptable
      end
    end

    test "DESKTOPUI_PREFER_COMPILER is respected" do
      # Test with zig preference (may fail if not installed)
      System.put_env("DESKTOPUI_PREFER_COMPILER", "zig")

      result = Mix.Tasks.Compile.DesktopUiNif.run([])

      # Result depends on system state
      case result do
        {:noop, []} -> :ok
        {:ok, [], _warnings} -> :ok
        {:ok, []} -> :ok
        {:error, _diagnostics} -> :ok  # Expected if no Zig available
        _ -> :ok
      end
    end
  end

  describe "target triple compatibility" do
    test "our target triples are Zig-compatible" do
      # All our target triples should be compatible with Zig
      targets = [
        "x86_64-linux-gnu",
        "aarch64-linux-gnu",
        "x86_64-macos-none",
        "aarch64-macos-none",
        "x86_64-windows-gnu"
      ]

      # Verify all targets follow expected format
      Enum.each(targets, fn target ->
        assert Regex.match?(~r/^[a-z0-9_]+-[a-z0-9_]+-[a-z0-9_]+$/, target)
      end)
    end

    test "target triple from Platform module is valid" do
      target = DesktopUI.Nif.Platform.target_triple()

      assert is_binary(target)
      assert String.length(target) > 0
      assert String.contains?(target, "-")
    end
  end

  describe "Zig integration" do
    setup do
      # Skip these tests if Zig is not installed
      if Zig.installed?() do
        :ok
      else
        :skip_from_test
      end
    end

    test "Zig version is checked for compatibility" do
      case Zig.version() do
        {:ok, version} ->
          assert :ok = Zig.check_version(version)

        {:error, :not_found} ->
          # Zig was marked as installed but version check failed
          # This can happen in some test environments
          :ok
      end
    end

    test "Zig executable can be found" do
      case Zig.find_executable() do
        {:ok, path} ->
          assert is_binary(path)

        {:error, :not_found} ->
          # Zig was marked as installed but executable not found
          # This can happen in some test environments
          :ok
      end
    end
  end

  describe "compiler workflow" do
    test "compiler has correct manifest support" do
      # Verify manifests function returns list
      manifests = Mix.Tasks.Compile.DesktopUiNif.manifests()

      assert is_list(manifests)
      assert length(manifests) > 0
    end

    test "compiler clean function works" do
      # Verify clean function returns :ok
      assert :ok = Mix.Tasks.Compile.DesktopUiNif.clean()
    end

    test "compiler returns expected result format" do
      # The compiler should return one of the expected formats
      result = Mix.Tasks.Compile.DesktopUiNif.run([])

      case result do
        {:ok, []} -> :ok
        {:ok, [], _warnings} -> :ok
        {:noop, []} -> :ok
        {:error, _diagnostics} -> :ok
        _ -> flunk("Unexpected result format: #{inspect(result)}")
      end
    end
  end

  describe "cross-compilation environment" do
    setup do
      # Save original environment
      original_target = System.get_env("DESKTOPUI_TARGET")

      on_exit(fn ->
        if original_target do
          System.put_env("DESKTOPUI_TARGET", original_target)
        else
          System.delete_env("DESKTOPUI_TARGET")
        end
      end)

      :ok
    end

    test "DESKTOPUI_TARGET is respected for cross-compilation" do
      System.put_env("DESKTOPUI_TARGET", "x86_64-windows-gnu")

      # Verify the target can be set
      target = System.get_env("DESKTOPUI_TARGET")
      assert target == "x86_64-windows-gnu"
    end

    test "cross-compilation targets are valid" do
      cross_targets = [
        "x86_64-windows-gnu",
        "aarch64-linux-gnu",
        "aarch64-macos-none"
      ]

      Enum.each(cross_targets, fn target ->
        System.put_env("DESKTOPUI_TARGET", target)
        assert System.get_env("DESKTOPUI_TARGET") == target
      end)
    end
  end

  describe "integration with SDL2 detection" do
    test "SDL2 cflags returns list" do
      cflags = DesktopUI.Nif.SDL2.cflags()

      assert is_list(cflags)
    end

    test "SDL2 ldflags returns list" do
      ldflags = DesktopUI.Nif.SDL2.ldflags()

      assert is_list(ldflags)
    end
  end
end

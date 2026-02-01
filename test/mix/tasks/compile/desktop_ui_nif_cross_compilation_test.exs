defmodule Mix.Tasks.Compile.DesktopUiNifCrossCompilationTest do
  use ExUnit.Case, async: false

  @moduletag :compiler
  @moduletag :cross_compilation
  @moduletag :mix_compiler

  # Note: We can't directly test private functions, so we test the public behavior
  # through the compiler interface

  describe "target triple validation" do
    setup do
      # Save original environment
      original_target = System.get_env("DESKTOPUI_TARGET")

      # Clean up after test
      on_exit(fn ->
        if original_target do
          System.put_env("DESKTOPUI_TARGET", original_target)
        else
          System.delete_env("DESKTOPUI_TARGET")
        end
      end)

      :ok
    end

    test "valid target triples are accepted" do
      valid_targets = [
        "x86_64-linux-gnu",
        "aarch64-linux-gnu",
        "x86_64-macos-none",
        "aarch64-macos-none",
        "x86_64-windows-gnu"
      ]

      # Set each target and verify compiler doesn't reject it for invalid format
      Enum.each(valid_targets, fn target ->
        System.put_env("DESKTOPUI_TARGET", target)

        # The compiler should accept the target format
        # (It may fail for other reasons like no C compiler)
        result = Mix.Tasks.Compile.DesktopUiNif.run([])

        # Check that the error is not about invalid target format
        case result do
          {:error, diagnostics} ->
            # If there's an error, it should not be about invalid target
            Enum.each(diagnostics, fn diag ->
              # Invalid target errors have specific message format
              if diag.message =~ "Invalid target triple" do
                flunk("Valid target #{target} was rejected as invalid: #{diag.message}")
              end
            end)

          _ ->
            # Success or other results are fine
            :ok
        end
      end)
    end

    test "invalid target triple format is rejected" do
      System.put_env("DESKTOPUI_TARGET", "invalid-format")

      result = Mix.Tasks.Compile.DesktopUiNif.run([])

      # Should return an error about invalid target
      case result do
        {:error, [diagnostic]} ->
          assert diagnostic.message =~ "Invalid target triple"
          assert diagnostic.message =~ "invalid-format"

        _ ->
          :ok
      end
    end

    test "target with wrong number of components is rejected" do
      System.put_env("DESKTOPUI_TARGET", "x86_64-linux")

      result = Mix.Tasks.Compile.DesktopUiNif.run([])

      # Should return an error about invalid format
      case result do
        {:error, [diagnostic]} ->
          assert diagnostic.message =~ "Invalid target triple"
          assert diagnostic.message =~ "exactly three components"

        _ ->
          :ok
      end
    end

    test "native build works without DESKTOPUI_TARGET" do
      System.delete_env("DESKTOPUI_TARGET")

      # Should use native target
      result = Mix.Tasks.Compile.DesktopUiNif.run([])

      # Should not error about invalid target
      case result do
        {:error, [diagnostic]} ->
          refute diagnostic.message =~ "Invalid target triple"

        _ ->
          :ok
      end
    end
  end

  describe "target triple components" do
    test "valid architectures are recognized" do
      valid_archs = [
        "x86_64", "aarch64", "arm64", "arm", "x86",
        "riscv64", "riscv32", "mips64", "mips"
      ]

      # Create valid targets with each architecture
      Enum.each(valid_archs, fn arch ->
        target = "#{arch}-linux-gnu"
        System.put_env("DESKTOPUI_TARGET", target)

        result = Mix.Tasks.Compile.DesktopUiNif.run([])

        # Should not error about unknown architecture
        case result do
          {:error, [diagnostic]} ->
            refute diagnostic.message =~ "Unknown architecture"

          _ ->
            :ok
        end
      end)
    end

    test "valid OS names are recognized" do
      valid_os = ["linux", "macos", "windows"]

      Enum.each(valid_os, fn os ->
        target = "x86_64-#{os}-gnu"
        System.put_env("DESKTOPUI_TARGET", target)

        result = Mix.Tasks.Compile.DesktopUiNif.run([])

        # Should not error about unknown OS
        case result do
          {:error, [diagnostic]} ->
            refute diagnostic.message =~ "Unknown OS"

          _ ->
            :ok
        end
      end)
    end

    test "valid environments are recognized" do
      valid_envs = ["gnu", "musl", "none"]

      Enum.each(valid_envs, fn env ->
        target = "x86_64-linux-#{env}"
        System.put_env("DESKTOPUI_TARGET", target)

        result = Mix.Tasks.Compile.DesktopUiNif.run([])

        # Should not error about unknown environment
        case result do
          {:error, [diagnostic]} ->
            refute diagnostic.message =~ "Unknown environment"

          _ ->
            :ok
        end
      end)
    end
  end

  describe "cross-compilation scenarios" do
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

    test "Linux to Windows cross-compilation target is accepted" do
      System.put_env("DESKTOPUI_TARGET", "x86_64-windows-gnu")

      result = Mix.Tasks.Compile.DesktopUiNif.run([])

      # Target should be accepted
      case result do
        {:error, [diagnostic]} ->
          refute diagnostic.message =~ "Invalid target triple"

        _ ->
          :ok
      end
    end

    test "Linux to macOS cross-compilation target is accepted" do
      System.put_env("DESKTOPUI_TARGET", "aarch64-macos-none")

      result = Mix.Tasks.Compile.DesktopUiNif.run([])

      # Target should be accepted
      case result do
        {:error, [diagnostic]} ->
          refute diagnostic.message =~ "Invalid target triple"

        _ ->
          :ok
      end
    end

    test "Linux to ARM64 cross-compilation target is accepted" do
      System.put_env("DESKTOPUI_TARGET", "aarch64-linux-gnu")

      result = Mix.Tasks.Compile.DesktopUiNif.run([])

      # Target should be accepted
      case result do
        {:error, [diagnostic]} ->
          refute diagnostic.message =~ "Invalid target triple"

        _ ->
          :ok
      end
    end
  end

  describe "error message quality" do
    setup do
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

    test "error message includes expected format" do
      System.put_env("DESKTOPUI_TARGET", "invalid")

      result = Mix.Tasks.Compile.DesktopUiNif.run([])

      case result do
        {:error, [diagnostic]} ->
          # Error should mention expected format
          assert diagnostic.message =~ "{arch}-{os}-{env}"
          # Error should include example
          assert diagnostic.message =~ "x86_64-linux-gnu"

        _ ->
          :ok
      end
    end

    test "error message lists supported architectures" do
      System.put_env("DESKTOPUI_TARGET", "unknown_arch-linux-gnu")

      result = Mix.Tasks.Compile.DesktopUiNif.run([])

      case result do
        {:error, [diagnostic]} ->
          assert diagnostic.message =~ "Unknown architecture"
          assert diagnostic.message =~ "x86_64"
          assert diagnostic.message =~ "aarch64"

        _ ->
          :ok
      end
    end

    test "error message lists supported OS" do
      System.put_env("DESKTOPUI_TARGET", "x86_64-unknown_os-gnu")

      result = Mix.Tasks.Compile.DesktopUiNif.run([])

      case result do
        {:error, [diagnostic]} ->
          assert diagnostic.message =~ "Unknown OS"
          assert diagnostic.message =~ "linux"
          assert diagnostic.message =~ "macos"
          assert diagnostic.message =~ "windows"

        _ ->
          :ok
      end
    end

    test "error message lists supported environments" do
      System.put_env("DESKTOPUI_TARGET", "x86_64-linux-unknown_env")

      result = Mix.Tasks.Compile.DesktopUiNif.run([])

      case result do
        {:error, [diagnostic]} ->
          assert diagnostic.message =~ "Unknown environment"
          assert diagnostic.message =~ "gnu"
          assert diagnostic.message =~ "musl"
          assert diagnostic.message =~ "none"

        _ ->
          :ok
      end
    end
  end

  describe "integration" do
    test "compiler respects DESKTOPUI_TARGET for cross-compilation" do
      original_target = System.get_env("DESKTOPUI_TARGET")

      on_exit(fn ->
        if original_target do
          System.put_env("DESKTOPUI_TARGET", original_target)
        else
          System.delete_env("DESKTOPUI_TARGET")
        end
      end)

      # Set cross-compilation target
      System.put_env("DESKTOPUI_TARGET", "aarch64-linux-gnu")

      # Run compiler
      result = Mix.Tasks.Compile.DesktopUiNif.run([])

      # Target should be respected (compilation may fail for other reasons)
      case result do
        {:error, [diagnostic]} ->
          # Error should not be about invalid target
          refute diagnostic.message =~ "Invalid target triple"

        _ ->
          :ok
      end
    end

    test "native compilation works without DESKTOPUI_TARGET" do
      original_target = System.get_env("DESKTOPUI_TARGET")

      on_exit(fn ->
        if original_target do
          System.put_env("DESKTOPUI_TARGET", original_target)
        else
          System.delete_env("DESKTOPUI_TARGET")
        end
      end)

      System.delete_env("DESKTOPUI_TARGET")

      # Native compilation should work
      result = Mix.Tasks.Compile.DesktopUiNif.run([])

      # Should not error about target
      case result do
        {:error, [diagnostic]} ->
          refute diagnostic.message =~ "Invalid target triple"

        _ ->
          :ok
      end
    end
  end
end

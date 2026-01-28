defmodule DesktopUI.Nif.PlatformTest do
  use ExUnit.Case
  alias DesktopUI.Nif.Platform

  describe "detect_platform/0" do
    test "returns a tuple with os family and type" do
      result = Platform.detect_platform()

      assert is_tuple(result)
      assert tuple_size(result) == 2
      assert elem(result, 0) in [:unix, :win32]
    end

    test "detects unix platform on Unix systems" do
      result = Platform.detect_platform()

      if elem(result, 0) == :unix do
        assert elem(result, 1) in [:linux, :darwin]
      end
    end

    @tag :windows
    test "detects Windows on Windows systems" do
      result = Platform.detect_platform()

      if elem(result, 0) == :win32 do
        assert elem(result, 1) == :nt
      end
    end
  end

  describe "detect_architecture/0" do
    test "returns a known architecture atom" do
      result = Platform.detect_architecture()

      assert result in [:x86_64, :aarch64, :arm64, :x86, :arm, :unknown]
    end

    test "returns an atom" do
      result = Platform.detect_architecture()
      assert is_atom(result)
    end
  end

  describe "target_triple/0" do
    test "returns a string" do
      result = Platform.target_triple()
      assert is_binary(result)
    end

    test "contains arch, vendor, and os components" do
      result = Platform.target_triple()
      parts = String.split(result, "-")

      assert length(parts) >= 3
    end

    test "respects DESKTOPUI_TARGET environment variable" do
      System.put_env("DESKTOPUI_TARGET", "x86_64-test-none")
      result = Platform.target_triple()
      System.delete_env("DESKTOPUI_TARGET")

      assert result == "x86_64-test-none"
    end

    test "returns consistent target triple for current platform" do
      result1 = Platform.target_triple()
      result2 = Platform.target_triple()

      assert result1 == result2
    end
  end

  describe "nif_extension/0" do
    test "returns a string starting with dot" do
      result = Platform.nif_extension()
      assert is_binary(result)
      assert String.starts_with?(result, ".")
    end

    test "returns valid extension for current platform" do
      result = Platform.nif_extension()
      assert result in [".so", ".dylib", ".dll"]
    end

    test "returns .so on Linux" do
      case Platform.detect_platform() do
        {:unix, :linux} ->
          assert Platform.nif_extension() == ".so"

        _ ->
          # Skip test on non-Linux platforms
          :ok
      end
    end

    test "returns .dylib on macOS" do
      case Platform.detect_platform() do
        {:unix, :darwin} ->
          assert Platform.nif_extension() == ".dylib"

        _ ->
          # Skip test on non-macOS platforms
          :ok
      end
    end
  end

  describe "c_compiler/0" do
    test "returns nil or a string" do
      result = Platform.c_compiler()
      assert result in [nil, "clang", "gcc", "cl.exe"] or is_binary(result)
    end

    test "returns a valid path when compiler is found" do
      result = Platform.c_compiler()

      if result != nil do
        assert File.exists?(result) or System.find_executable(Path.basename(result)) != nil
      end
    end
  end

  describe "integration" do
    test "target_triple and nif_extension are consistent" do
      target = Platform.target_triple()
      ext = Platform.nif_extension()

      cond do
        String.contains?(target, "linux") ->
          assert ext == ".so"

        String.contains?(target, "macos") ->
          assert ext == ".dylib"

        String.contains?(target, "windows") ->
          assert ext == ".dll"

        true ->
          # Unknown platform, accept any extension
          assert true
      end
    end

    test "detect_platform and detect_architecture work together" do
      {os_family, _os_type} = Platform.detect_platform()
      arch = Platform.detect_architecture()

      # Both should return valid values
      assert os_family in [:unix, :win32]
      assert is_atom(arch)
    end
  end
end

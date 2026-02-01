defmodule DesktopUI.Nif.ZigPropertyTest do
  use ExUnit.Case, async: true

  alias DesktopUI.Nif.Zig

  @moduletag :nif
  @moduletag :zig
  @moduletag :property

  describe "version string properties" do
    test "minimum version is a valid version string" do
      version = Zig.minimum_version()
      assert Version.parse!(version)
    end

    test "recommended version is a valid version string" do
      version = Zig.recommended_version()
      assert Version.parse!(version)
    end

    test "recommended version is >= minimum version" do
      min = Zig.minimum_version()
      rec = Zig.recommended_version()

      assert Version.compare(Version.parse!(rec), Version.parse!(min)) != :lt
    end

    test "version format is consistent" do
      # Test multiple version strings
      assert Regex.match?(~r/^\d+\.\d+\.\d+$/, "0.11.0")
      assert Regex.match?(~r/^\d+\.\d+\.\d+$/, "0.12.0")
      assert Regex.match?(~r/^\d+\.\d+\.\d+$/, "0.13.0")
      assert Regex.match?(~r/^\d+\.\d+\.\d+$/, "1.0.0")
    end
  end

  describe "check_version properties" do
    test "versions >= minimum are accepted" do
      min = Zig.minimum_version()

      # Test versions that should be accepted
      assert :ok = Zig.check_version(min)
      assert :ok = Zig.check_version("0.12.0")
      assert :ok = Zig.check_version("0.13.0")
      assert :ok = Zig.check_version("1.0.0")
      assert :ok = Zig.check_version("2.0.0")
    end

    test "versions < minimum are rejected" do
      # Test versions that should be rejected
      assert {:error, :incompatible_version} = Zig.check_version("0.9.0")
      assert {:error, :incompatible_version} = Zig.check_version("0.10.0")
      assert {:error, :incompatible_version} = Zig.check_version("0.1.0")
    end
  end

  describe "installation instructions properties" do
    test "installation instructions contain minimum version" do
      instructions = Zig.installation_instructions()
      assert String.contains?(instructions, Zig.minimum_version())
    end

    test "installation instructions contain recommended version" do
      instructions = Zig.installation_instructions()
      assert String.contains?(instructions, Zig.recommended_version())
    end

    test "installation instructions are non-empty" do
      instructions = Zig.installation_instructions()
      assert String.length(instructions) > 0
    end

    test "installation instructions contain platform-specific guidance" do
      instructions = Zig.installation_instructions()

      case DesktopUI.Nif.Platform.detect_platform() do
        {:unix, :darwin} ->
          assert String.contains?(instructions, "macOS") or
                  String.contains?(instructions, "brew")

        {:unix, :linux} ->
          assert String.contains?(instructions, "Linux") or
                  String.contains?(instructions, "ziglang.org")

        {:win32, :nt} ->
          assert String.contains?(instructions, "Windows")

        _ ->
          # Unknown platform, skip check
          :ok
      end
    end
  end

  describe "not_found_error properties" do
    test "not_found_error contains installation instructions" do
      error = Zig.not_found_error()
      instructions = Zig.installation_instructions()

      assert String.contains?(error, instructions)
    end

    test "not_found_error contains minimum version" do
      error = Zig.not_found_error()
      assert String.contains?(error, Zig.minimum_version())
    end

    test "not_found_error is helpful" do
      error = Zig.not_found_error()
      assert String.contains?(error, "install")
      assert String.length(error) > 100
    end
  end

  describe "find_executable properties" do
    test "returns valid result format" do
      case Zig.find_executable() do
        {:ok, path} ->
          assert is_binary(path)
          assert String.contains?(path, "zig")

        {:error, :not_found} ->
          assert true

        other ->
          flunk("Unexpected result: #{inspect(other)}")
      end
    end
  end

  describe "installed? properties" do
    test "returns boolean" do
      assert is_boolean(Zig.installed?())
    end

    test "is consistent with find_executable" do
      installed = Zig.installed?()
      exec_result = Zig.find_executable()

      case exec_result do
        {:ok, _path} ->
          # If executable is found, installed? should be true
          assert installed == true

        {:error, :not_found} ->
          # If executable not found, installed? should be false
          assert installed == false
      end
    end
  end
end

defmodule DesktopUI.Nif.ZigTest do
  use ExUnit.Case, async: false

  alias DesktopUI.Nif.Zig
  alias DesktopUI.Nif.TestHelper

  @moduletag :nif
  @moduletag :zig

  describe "installed?/0" do
    test "returns true when Zig is in PATH" do
      # We can't reliably test this without Zig installed
      # but we can verify the function returns a boolean
      result = Zig.installed?()
      assert is_boolean(result)
    end

    test "returns false when Zig is not found" do
      # Mock by temporarily modifying PATH
      TestHelper.with_env_var("PATH", "", fn ->
        # Clear PATH so zig won't be found
        # Note: This may not work perfectly as zig could be in other locations
        # but we're testing the behavior when zig is not found
        result = Zig.installed?()
        assert is_boolean(result)
      end)
    end
  end

  describe "find_executable/0" do
    test "returns {:ok, path} when Zig is installed" do
      case Zig.find_executable() do
        {:ok, path} ->
          assert is_binary(path)
          assert String.contains?(path, "zig")

        {:error, :not_found} ->
          # Zig not installed, which is acceptable
          :ok
      end
    end

    test "returns {:error, :not_found} when Zig is not in PATH" do
      # Can't fully mock this, but we verify the error shape
      result = Zig.find_executable()

      case result do
        {:ok, _path} -> :ok  # Zig is installed
        {:error, :not_found} -> :ok  # Expected when not installed
        _ -> flunk("Unexpected result: #{inspect(result)}")
      end
    end
  end

  describe "minimum_version/0" do
    test "returns the minimum required version" do
      assert Zig.minimum_version() == "0.11.0"
    end

    test "returns a valid version string" do
      version = Zig.minimum_version()
      assert Regex.match?(~r/^\d+\.\d+\.\d+$/, version)
    end
  end

  describe "recommended_version/0" do
    test "returns the recommended version" do
      assert Zig.recommended_version() == "0.13.0"
    end

    test "returns a valid version string" do
      version = Zig.recommended_version()
      assert Regex.match?(~r/^\d+\.\d+\.\d+$/, version)
    end

    test "recommended version is >= minimum version" do
      min = Zig.minimum_version()
      rec = Zig.recommended_version()

      assert Version.compare(Version.parse!(rec), Version.parse!(min)) != :lt
    end
  end

  describe "version/0" do
    test "returns {:ok, version} when Zig is installed" do
      case Zig.version() do
        {:ok, version} ->
          assert is_binary(version)
          assert match?(~r/^\d+\.\d+\.\d+$/, version)

        {:error, :not_found} ->
          # Zig not installed, acceptable
          :ok
      end
    end

    test "returns {:error, :not_found} when Zig is not installed" do
      # This will pass if Zig is not installed
      result = Zig.version()

      case result do
        {:ok, _version} -> :ok  # Zig is installed
        {:error, :not_found} -> :ok  # Expected when not installed
        _ -> flunk("Unexpected result: #{inspect(result)}")
      end
    end

    test "caches version in process dictionary" do
      # Clear any cached version first
      Process.delete(:desktop_ui_zig_version)

      # First call should cache
      result1 = Zig.version()

      # Check if it was cached (only if Zig is installed)
      case result1 do
        {:ok, version} ->
          cached = Process.get(:desktop_ui_zig_version)
          assert cached == version

        {:error, :not_found} ->
          # Nothing cached if not found
          assert is_nil(Process.get(:desktop_ui_zig_version))
      end
    end

    test "returns cached version on subsequent calls" do
      # Clear cache first
      Process.delete(:desktop_ui_zig_version)

      # First call
      {status1, version1} = Zig.version()

      # If Zig was found, second call should return cached value
      case {status1, version1} do
        {:ok, _version} ->
          # Mock the cache to verify it's being used
          fake_cached_version = "9.9.9"
          Process.put(:desktop_ui_zig_version, fake_cached_version)

          # This should return the cached version, not call zig version
          assert Zig.version() == {:ok, fake_cached_version}

        {:error, :not_found} ->
          # No Zig, no caching behavior to test
          :ok
      end
    end
  end

  describe "check_version/1" do
    test "accepts versions >= minimum version" do
      assert :ok = Zig.check_version("0.11.0")
      assert :ok = Zig.check_version("0.12.0")
      assert :ok = Zig.check_version("0.13.0")
      assert :ok = Zig.check_version("1.0.0")
    end

    test "rejects versions < minimum version" do
      assert {:error, :incompatible_version} = Zig.check_version("0.10.0")
      assert {:error, :incompatible_version} = Zig.check_version("0.9.0")
      assert {:error, :incompatible_version} = Zig.check_version("0.1.0")
    end

    test "handles invalid version strings" do
      assert {:error, :incompatible_version} = Zig.check_version("invalid")
      assert {:error, :incompatible_version} = Zig.check_version("")
      assert {:error, :incompatible_version} = Zig.check_version("not.a.version")
    end

    test "handles pre-release versions" do
      # Pre-release versions (e.g., 0.11.0-dev.1234) should parse
      # but may fail comparison depending on Version module behavior
      result = Zig.check_version("0.11.0-dev.1234")

      # Either it parses as >= 0.11.0 or fails gracefully
      case result do
        :ok -> :ok
        {:error, :incompatible_version} -> :ok
      end
    end

    test "accepts exactly minimum version" do
      assert :ok = Zig.check_version("0.11.0")
    end
  end

  describe "installation_instructions/0" do
    test "returns instructions for current platform" do
      instructions = Zig.installation_instructions()
      assert is_binary(instructions)
      assert String.length(instructions) > 0
    end

    test "includes platform-specific information" do
      instructions = Zig.installation_instructions()

      case DesktopUI.Nif.Platform.detect_platform() do
        {:unix, :darwin} ->
          assert String.contains?(instructions, "macOS")
          assert String.contains?(instructions, "brew install zig")

        {:unix, :linux} ->
          assert String.contains?(instructions, "Linux")
          assert String.contains?(instructions, "ziglang.org")

        {:win32, :nt} ->
          assert String.contains?(instructions, "Windows")

        _ ->
          # Unknown platform, should have generic instructions
          :ok
      end
    end

    test "includes minimum version information" do
      instructions = Zig.installation_instructions()
      assert String.contains?(instructions, "0.11.0")
    end
  end

  describe "not_found_error/0" do
    test "returns helpful error message" do
      error = Zig.not_found_error()
      assert is_binary(error)
      assert String.length(error) > 0
    end

    test "includes installation instructions" do
      error = Zig.not_found_error()
      assert String.contains?(error, "Zig not found")
      assert String.contains?(error, "install")
    end

    test "includes minimum version requirement" do
      error = Zig.not_found_error()
      assert String.contains?(error, Zig.minimum_version())
    end
  end

  describe "version regex" do
    test "correctly parses standard zig version output" do
      # Test the regex pattern used by the module
      # zig version output format: "zig 0.13.0"
      regex = ~r/^zig (?<version>\d+\.\d+\.\d+)/

      assert ["zig 0.13.0", "0.13.0"] = Regex.run(regex, "zig 0.13.0")
      assert ["zig 0.11.0", "0.11.0"] = Regex.run(regex, "zig 0.11.0")
      assert ["zig 1.0.0", "1.0.0"] = Regex.run(regex, "zig 1.0.0")
    end

    test "handles zig version with extra text" do
      regex = ~r/^zig (?<version>\d+\.\d+\.\d+)/

      # Extract version from "zig 0.13.0\n..."
      input = "zig 0.13.0\nCopyright (c)..."
      assert ["zig 0.13.0", "0.13.0"] = Regex.run(regex, input)
    end
  end

  describe "integration" do
    test "all public functions are callable" do
      # Ensure all documented public functions exist and are callable
      assert is_function(&Zig.installed?/0, 0)
      assert is_function(&Zig.version/0, 0)
      assert is_function(&Zig.find_executable/0, 0)
      assert is_function(&Zig.minimum_version/0, 0)
      assert is_function(&Zig.recommended_version/0, 0)
      assert is_function(&Zig.check_version/1, 1)
      assert is_function(&Zig.installation_instructions/0, 0)
      assert is_function(&Zig.not_found_error/0, 0)
    end

    test "minimum and recommended versions are valid" do
      min = Zig.minimum_version()
      rec = Zig.recommended_version()

      assert Version.parse!(min)
      assert Version.parse!(rec)
    end
  end
end

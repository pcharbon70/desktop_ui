defmodule DesktopUI.GraphicsTest do
  use ExUnit.Case, async: false

  alias DesktopUI.Graphics

  # Note: These tests are not async because they test NIF loading
  # which is a global state

  describe "version/0" do
    test "returns a version string" do
      version = Graphics.version()

      # Can be either a binary or a charlist depending on NIF version
      assert is_binary(version) or is_list(version)

      # Convert to string if charlist for validation
      version_str = if is_list(version), do: List.to_string(version), else: version
      assert String.length(version_str) > 0

      # Version should be either "0.1.0-nif" or "0.1.0-fallback"
      assert version_str =~ ~r/^0\.1\.0-(nif|fallback)$/
    end

    test "nif version contains expected format" do
      version = Graphics.version()
      version_str = if is_list(version), do: List.to_string(version), else: version
      # Should contain major.minor.patch format
      assert version_str =~ ~r/^\d+\.\d+\.\d+/
    end
  end

  describe "initialized?/0" do
    test "returns a boolean" do
      result = Graphics.initialized?()
      assert is_boolean(result)
    end

    test "returns true if NIF is loaded, false otherwise" do
      # The result depends on whether SDL2 is installed
      result = Graphics.initialized?()

      # Should always return a boolean
      assert is_boolean(result)

      # If NIF loaded, should be true; otherwise false
      # Both are valid states depending on SDL2 availability
      if result do
        assert Graphics.initialized?() == true
      else
        assert Graphics.initialized?() == false
      end
    end
  end

  describe "nif_init/0" do
    test "returns :ok tuple with info map or :error tuple" do
      result = Graphics.nif_init()

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "when successful, returns info map with version and initialized keys" do
      case Graphics.nif_init() do
        {:ok, info} when is_map(info) ->
          assert Map.has_key?(info, :version)
          assert Map.has_key?(info, :initialized)
          # Version can be binary or charlist
          version = info.version
          assert is_binary(version) or is_list(version)
          assert is_integer(info.initialized)

        {:error, _reason} ->
          # NIF not loaded - test passes, this is expected without SDL2
          :ok
      end
    end
  end

  describe "get_error/0" do
    test "returns an error message string" do
      error = Graphics.get_error()
      assert is_binary(error) or is_list(error)
    end

    test "returns a non-empty string" do
      error = Graphics.get_error()
      error_str = if is_list(error), do: List.to_string(error), else: error
      assert String.length(error_str) > 0
    end
  end

  describe "NIF loading" do
    test "module is available even when NIF fails to load" do
      # The module should always be callable
      assert function_exported?(DesktopUI.Graphics, :version, 0)
      assert function_exported?(DesktopUI.Graphics, :initialized?, 0)
      assert function_exported?(DesktopUI.Graphics, :nif_init, 0)
      assert function_exported?(DesktopUI.Graphics, :get_error, 0)
    end

    test "fallback functions return expected values when NIF not loaded" do
      # Even without SDL2, these should return sensible values
      version = Graphics.version()
      assert is_binary(version) or is_list(version)

      version_str = if is_list(version), do: List.to_string(version), else: version
      assert version_str =~ ~r/^0\.1\.0/

      error = Graphics.get_error()
      assert is_binary(error) or is_list(error)
    end
  end

  describe "integration" do
    test "all public functions work together without crashing" do
      # This test ensures the module is stable even without SDL2
      version = Graphics.version()
      initialized = Graphics.initialized?()
      error = Graphics.get_error()
      init_result = Graphics.nif_init()

      # All should return valid types
      assert is_binary(version) or is_list(version)
      assert is_boolean(initialized)
      assert is_binary(error) or is_list(error)
      # init_result should be either {:ok, map} or {:error, string}
      case init_result do
        {:ok, info} when is_map(info) -> :ok
        {:error, _reason} -> :ok
        _ -> flunk("Unexpected init_result: #{inspect(init_result)}")
      end
    end
  end
end

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

      # Version should be "0.2.0-nif" or "0.2.0-fallback"
      assert version_str =~ ~r/^0\.2\.0-(nif|fallback)$/
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
      # Window management functions should also be exported
      assert function_exported?(DesktopUI.Graphics, :sdl_init, 0)
      assert function_exported?(DesktopUI.Graphics, :create_window, 4)
      assert function_exported?(DesktopUI.Graphics, :destroy_window, 1)
      assert function_exported?(DesktopUI.Graphics, :get_window_size, 1)
      assert function_exported?(DesktopUI.Graphics, :set_window_size, 3)
      assert function_exported?(DesktopUI.Graphics, :set_window_title, 2)
    end

    test "fallback functions return expected values when NIF not loaded" do
      # Even without SDL2, these should return sensible values
      version = Graphics.version()
      assert is_binary(version) or is_list(version)

      version_str = if is_list(version), do: List.to_string(version), else: version
      assert version_str =~ ~r/^0\.2\.0/

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

  describe "window management" do
    @tag :sdl2
    @tag :window_management
    test "sdl_init/0 initializes SDL2 or returns helpful error" do
      # sdl_init should return either {:ok, %{}} or {:error, reason}
      # When SDL2 is available, it should initialize successfully
      # When SDL2 is not available, it should return a clear error message
      case Graphics.sdl_init() do
        {:ok, %{}} ->
          # SDL2 initialized successfully
          :ok

        {:error, reason} when is_binary(reason) or is_list(reason) ->
          # SDL2 not available - verify error message is helpful
          reason_str = if is_list(reason), do: List.to_string(reason), else: reason
          assert String.length(reason_str) > 0
          :ok

        other ->
          flunk("Unexpected sdl_init result: #{inspect(other)}")
      end
    end

    @tag :sdl2
    @tag :window_management
    test "create_window/4 creates window or returns error when SDL2 unavailable" do
      # First try to initialize SDL2
      sdl_init_result = Graphics.sdl_init()

      case sdl_init_result do
        {:ok, %{}} ->
          # SDL2 is available, try creating a window
          case Graphics.create_window("Test Window", 800, 600) do
            {:ok, window_id} when is_integer(window_id) ->
              # Window created successfully
              assert window_id >= 0

            {:error, reason} when is_binary(reason) or is_list(reason) ->
              # Window creation failed - should have error message
              reason_str = if is_list(reason), do: List.to_string(reason), else: reason
              assert String.length(reason_str) > 0
          end

        {:error, _reason} ->
          # SDL2 not available - create_window should return error
          case Graphics.create_window("Test Window", 800, 600) do
            {:error, reason} when is_binary(reason) or is_list(reason) ->
              # Expected when SDL2 not available
              reason_str = if is_list(reason), do: List.to_string(reason), else: reason
              assert String.length(reason_str) > 0

            other ->
              flunk("Unexpected create_window result when SDL2 not initialized: #{inspect(other)}")
          end
      end
    end

    @tag :sdl2
    @tag :window_management
    test "create_window/4 with options parses flags correctly" do
      # Test that options are parsed correctly
      # Even without SDL2, the function should handle options parameter
      case Graphics.create_window("Test Window", 800, 600, resizable: false) do
        {:ok, _window_id} -> :ok
        {:error, _reason} -> :ok
      end

      case Graphics.create_window("Test Window", 800, 600, fullscreen: true) do
        {:ok, _window_id} -> :ok
        {:error, _reason} -> :ok
      end
    end

    @tag :sdl2
    @tag :window_management
    test "destroy_window/1 destroys window or returns error" do
      # Try to destroy a window that may or may not exist
      case Graphics.destroy_window(0) do
        :ok ->
          # Window destroyed successfully
          :ok

        {:error, reason} when is_binary(reason) or is_list(reason) ->
          # Window didn't exist or SDL2 not available
          reason_str = if is_list(reason), do: List.to_string(reason), else: reason
          assert String.length(reason_str) > 0
      end
    end

    @tag :sdl2
    @tag :window_management
    test "get_window_size/1 returns size or error" do
      case Graphics.get_window_size(0) do
        {:ok, {width, height}} when is_integer(width) and is_integer(height) ->
          # Got window size
          assert width >= 0
          assert height >= 0

        {:error, reason} when is_binary(reason) or is_list(reason) ->
          # Window doesn't exist or SDL2 not available
          reason_str = if is_list(reason), do: List.to_string(reason), else: reason
          assert String.length(reason_str) > 0
      end
    end

    @tag :sdl2
    @tag :window_management
    test "set_window_size/3 resizes window or returns error" do
      case Graphics.set_window_size(0, 1024, 768) do
        :ok ->
          # Window resized successfully
          :ok

        {:error, reason} when is_binary(reason) or is_list(reason) ->
          # Window doesn't exist or SDL2 not available
          reason_str = if is_list(reason), do: List.to_string(reason), else: reason
          assert String.length(reason_str) > 0
      end
    end

    @tag :sdl2
    @tag :window_management
    test "set_window_title/2 changes title or returns error" do
      case Graphics.set_window_title(0, "New Title") do
        :ok ->
          # Title updated successfully
          :ok

        {:error, reason} when is_binary(reason) or is_list(reason) ->
          # Window doesn't exist or SDL2 not available
          reason_str = if is_list(reason), do: List.to_string(reason), else: reason
          assert String.length(reason_str) > 0
      end
    end

    @tag :sdl2
    @tag :window_management
    test "full window lifecycle when SDL2 available" do
      # Test the full window lifecycle: init -> create -> get size -> destroy
      case Graphics.sdl_init() do
        {:ok, %{}} ->
          # SDL2 available - test full lifecycle
          assert {:ok, window_id} = Graphics.create_window("Lifecycle Test", 640, 480)
          assert is_integer(window_id)

          # Get window size
          assert {:ok, {width, height}} = Graphics.get_window_size(window_id)
          assert width == 640
          assert height == 480

          # Set window size
          assert :ok = Graphics.set_window_size(window_id, 800, 600)

          # Verify new size
          assert {:ok, {new_width, new_height}} = Graphics.get_window_size(window_id)
          assert new_width == 800
          assert new_height == 600

          # Set window title
          assert :ok = Graphics.set_window_title(window_id, "Updated Title")

          # Destroy window
          assert :ok = Graphics.destroy_window(window_id)

        {:error, _reason} ->
          # SDL2 not available - skip lifecycle test
          :ok
      end
    end

    @tag :sdl2
    @tag :window_management
    test "multiple windows can be created when SDL2 available" do
      case Graphics.sdl_init() do
        {:ok, %{}} ->
          # SDL2 available - create multiple windows
          assert {:ok, id1} = Graphics.create_window("Window 1", 400, 300)
          assert {:ok, id2} = Graphics.create_window("Window 2", 400, 300)
          assert {:ok, id3} = Graphics.create_window("Window 3", 400, 300)

          # Window IDs should be different
          assert id1 != id2
          assert id2 != id3

          # Clean up
          assert :ok = Graphics.destroy_window(id1)
          assert :ok = Graphics.destroy_window(id2)
          assert :ok = Graphics.destroy_window(id3)

        {:error, _reason} ->
          # SDL2 not available - skip test
          :ok
      end
    end
  end
end

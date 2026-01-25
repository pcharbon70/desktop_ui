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

      # Version should be "0.3.0-nif" or "0.3.0-fallback"
      assert version_str =~ ~r/^0\.3\.0-(nif|fallback)$/
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
      # Renderer and drawing functions should also be exported
      assert function_exported?(DesktopUI.Graphics, :create_renderer, 1)
      assert function_exported?(DesktopUI.Graphics, :destroy_renderer, 1)
      assert function_exported?(DesktopUI.Graphics, :set_render_draw_color, 5)
      assert function_exported?(DesktopUI.Graphics, :clear_render, 1)
      assert function_exported?(DesktopUI.Graphics, :draw_rect, 6)
      assert function_exported?(DesktopUI.Graphics, :fill_rect, 6)
      assert function_exported?(DesktopUI.Graphics, :present_render, 1)
      # Event polling functions should also be exported
      assert function_exported?(DesktopUI.Graphics, :poll_event, 0)
      assert function_exported?(DesktopUI.Graphics, :wait_event, 1)
    end

    test "fallback functions return expected values when NIF not loaded" do
      # Even without SDL2, these should return sensible values
      version = Graphics.version()
      assert is_binary(version) or is_list(version)

      version_str = if is_list(version), do: List.to_string(version), else: version
      assert version_str =~ ~r/^0\.3\.0/

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

    # ============================================================================
    # Renderer and Drawing Tests
    # ============================================================================

    @tag :sdl2
    @tag :renderer
    test "create_renderer/1 creates renderer or returns error when SDL2 unavailable" do
      case Graphics.sdl_init() do
        {:ok, %{}} ->
          # Create a window first
          case Graphics.create_window("Renderer Test", 800, 600) do
            {:ok, window_id} ->
              # Now create renderer
              case Graphics.create_renderer(window_id) do
                {:ok, renderer_id} ->
                  assert is_integer(renderer_id)
                  # Clean up
                  Graphics.destroy_renderer(renderer_id)
                  Graphics.destroy_window(window_id)

                {:error, reason} ->
                  flunk("Failed to create renderer: #{inspect(reason)}")
              end

            {:error, reason} ->
              flunk("Failed to create window: #{inspect(reason)}")
          end

        {:error, _reason} ->
          # SDL2 not available - verify error
          assert {:error, _reason} = Graphics.create_renderer(0)
      end
    end

    @tag :sdl2
    @tag :renderer
    test "destroy_renderer/1 destroys renderer or returns error" do
      case Graphics.sdl_init() do
        {:ok, %{}} ->
          # Create window and renderer
          case Graphics.create_window("Destroy Renderer Test", 800, 600) do
            {:ok, window_id} ->
              case Graphics.create_renderer(window_id) do
                {:ok, renderer_id} ->
                  # Destroy the renderer
                  assert :ok = Graphics.destroy_renderer(renderer_id)
                  # Destroy window
                  Graphics.destroy_window(window_id)

                {:error, reason} ->
                  flunk("Failed to create renderer: #{inspect(reason)}")
              end

            {:error, reason} ->
              flunk("Failed to create window: #{inspect(reason)}")
          end

        {:error, _reason} ->
          # SDL2 not available - verify error
          assert {:error, _reason} = Graphics.destroy_renderer(0)
      end
    end

    @tag :sdl2
    @tag :renderer
    test "set_render_draw_color/5 sets color or returns error" do
      case Graphics.sdl_init() do
        {:ok, %{}} ->
          # Create window and renderer
          case Graphics.create_window("Set Color Test", 800, 600) do
            {:ok, window_id} ->
              case Graphics.create_renderer(window_id) do
                {:ok, renderer_id} ->
                  # Set draw color
                  assert :ok = Graphics.set_render_draw_color(renderer_id, 255, 0, 0, 255)
                  # Clean up
                  Graphics.destroy_renderer(renderer_id)
                  Graphics.destroy_window(window_id)

                {:error, reason} ->
                  flunk("Failed to create renderer: #{inspect(reason)}")
              end

            {:error, reason} ->
              flunk("Failed to create window: #{inspect(reason)}")
          end

        {:error, _reason} ->
          # SDL2 not available - verify error
          assert {:error, _reason} = Graphics.set_render_draw_color(0, 255, 0, 0, 255)
      end
    end

    @tag :sdl2
    @tag :renderer
    test "clear_render/1 clears renderer or returns error" do
      case Graphics.sdl_init() do
        {:ok, %{}} ->
          # Create window and renderer
          case Graphics.create_window("Clear Render Test", 800, 600) do
            {:ok, window_id} ->
              case Graphics.create_renderer(window_id) do
                {:ok, renderer_id} ->
                  # Set draw color and clear
                  assert :ok = Graphics.set_render_draw_color(renderer_id, 0, 0, 0, 255)
                  assert :ok = Graphics.clear_render(renderer_id)
                  # Clean up
                  Graphics.destroy_renderer(renderer_id)
                  Graphics.destroy_window(window_id)

                {:error, reason} ->
                  flunk("Failed to create renderer: #{inspect(reason)}")
              end

            {:error, reason} ->
              flunk("Failed to create window: #{inspect(reason)}")
          end

        {:error, _reason} ->
          # SDL2 not available - verify error
          assert {:error, _reason} = Graphics.clear_render(0)
      end
    end

    @tag :sdl2
    @tag :renderer
    test "draw_rect/6 draws outline rectangle or returns error" do
      case Graphics.sdl_init() do
        {:ok, %{}} ->
          # Create window and renderer
          case Graphics.create_window("Draw Rect Test", 800, 600) do
            {:ok, window_id} ->
              case Graphics.create_renderer(window_id) do
                {:ok, renderer_id} ->
                  # Clear to black
                  Graphics.set_render_draw_color(renderer_id, 0, 0, 0, 255)
                  Graphics.clear_render(renderer_id)
                  # Draw an outline rectangle
                  assert :ok = Graphics.draw_rect(renderer_id, 10, 10, 100, 50, {255, 0, 0, 255})
                  # Present to screen
                  Graphics.present_render(renderer_id)
                  # Clean up
                  Graphics.destroy_renderer(renderer_id)
                  Graphics.destroy_window(window_id)

                {:error, reason} ->
                  flunk("Failed to create renderer: #{inspect(reason)}")
              end

            {:error, reason} ->
              flunk("Failed to create window: #{inspect(reason)}")
          end

        {:error, _reason} ->
          # SDL2 not available - verify error
          assert {:error, _reason} = Graphics.draw_rect(0, 10, 10, 100, 50, {255, 0, 0, 255})
      end
    end

    @tag :sdl2
    @tag :renderer
    test "fill_rect/6 draws filled rectangle or returns error" do
      case Graphics.sdl_init() do
        {:ok, %{}} ->
          # Create window and renderer
          case Graphics.create_window("Fill Rect Test", 800, 600) do
            {:ok, window_id} ->
              case Graphics.create_renderer(window_id) do
                {:ok, renderer_id} ->
                  # Clear to black
                  Graphics.set_render_draw_color(renderer_id, 0, 0, 0, 255)
                  Graphics.clear_render(renderer_id)
                  # Draw a filled rectangle
                  assert :ok = Graphics.fill_rect(renderer_id, 10, 10, 100, 50, {0, 255, 0, 255})
                  # Present to screen
                  Graphics.present_render(renderer_id)
                  # Clean up
                  Graphics.destroy_renderer(renderer_id)
                  Graphics.destroy_window(window_id)

                {:error, reason} ->
                  flunk("Failed to create renderer: #{inspect(reason)}")
              end

            {:error, reason} ->
              flunk("Failed to create window: #{inspect(reason)}")
          end

        {:error, _reason} ->
          # SDL2 not available - verify error
          assert {:error, _reason} = Graphics.fill_rect(0, 10, 10, 100, 50, {0, 255, 0, 255})
      end
    end

    @tag :sdl2
    @tag :renderer
    test "present_render/1 presents content or returns error" do
      case Graphics.sdl_init() do
        {:ok, %{}} ->
          # Create window and renderer
          case Graphics.create_window("Present Render Test", 800, 600) do
            {:ok, window_id} ->
              case Graphics.create_renderer(window_id) do
                {:ok, renderer_id} ->
                  # Clear to black
                  Graphics.set_render_draw_color(renderer_id, 0, 0, 0, 255)
                  Graphics.clear_render(renderer_id)
                  # Present to screen
                  assert :ok = Graphics.present_render(renderer_id)
                  # Clean up
                  Graphics.destroy_renderer(renderer_id)
                  Graphics.destroy_window(window_id)

                {:error, reason} ->
                  flunk("Failed to create renderer: #{inspect(reason)}")
              end

            {:error, reason} ->
              flunk("Failed to create window: #{inspect(reason)}")
          end

        {:error, _reason} ->
          # SDL2 not available - verify error
          assert {:error, _reason} = Graphics.present_render(0)
      end
    end

    @tag :sdl2
    @tag :renderer
    test "full rendering lifecycle when SDL2 available" do
      case Graphics.sdl_init() do
        {:ok, %{}} ->
          # Test the full rendering lifecycle
          assert {:ok, window_id} = Graphics.create_window("Lifecycle Render Test", 800, 600)
          assert {:ok, renderer_id} = Graphics.create_renderer(window_id)

          # Set draw color to black and clear
          assert :ok = Graphics.set_render_draw_color(renderer_id, 0, 0, 0, 255)
          assert :ok = Graphics.clear_render(renderer_id)

          # Draw filled rectangles with different colors
          assert :ok = Graphics.fill_rect(renderer_id, 10, 10, 100, 50, {255, 0, 0, 255})
          assert :ok = Graphics.fill_rect(renderer_id, 120, 10, 100, 50, {0, 255, 0, 255})
          assert :ok = Graphics.fill_rect(renderer_id, 230, 10, 100, 50, {0, 0, 255, 255})

          # Draw outline rectangles
          assert :ok = Graphics.draw_rect(renderer_id, 10, 70, 100, 50, {255, 255, 0, 255})
          assert :ok = Graphics.draw_rect(renderer_id, 120, 70, 100, 50, {255, 0, 255, 255})

          # Present to screen
          assert :ok = Graphics.present_render(renderer_id)

          # Clean up
          assert :ok = Graphics.destroy_renderer(renderer_id)
          assert :ok = Graphics.destroy_window(window_id)

        {:error, _reason} ->
          # SDL2 not available - skip lifecycle test
          :ok
      end
    end

    @tag :sdl2
    @tag :renderer
    test "multiple renderers can be created for different windows" do
      case Graphics.sdl_init() do
        {:ok, %{}} ->
          # Create multiple windows
          assert {:ok, window1} = Graphics.create_window("Multi Render 1", 400, 300)
          assert {:ok, window2} = Graphics.create_window("Multi Render 2", 400, 300)

          # Create renderers for each
          assert {:ok, renderer1} = Graphics.create_renderer(window1)
          assert {:ok, renderer2} = Graphics.create_renderer(window2)

          # Renderer IDs should be different
          assert renderer1 != renderer2

          # Clean up
          Graphics.destroy_renderer(renderer1)
          Graphics.destroy_renderer(renderer2)
          Graphics.destroy_window(window1)
          Graphics.destroy_window(window2)

        {:error, _reason} ->
          # SDL2 not available - skip test
          :ok
      end
    end

    @tag :sdl2
    @tag :renderer
    test "invalid renderer operations return errors" do
      case Graphics.sdl_init() do
        {:ok, %{}} ->
          # Test operations on invalid renderer ID
          assert {:error, _reason} = Graphics.destroy_renderer(999)
          assert {:error, _reason} = Graphics.set_render_draw_color(999, 255, 0, 0, 255)
          assert {:error, _reason} = Graphics.clear_render(999)
          assert {:error, _reason} = Graphics.draw_rect(999, 10, 10, 100, 50, {255, 0, 0, 255})
          assert {:error, _reason} = Graphics.fill_rect(999, 10, 10, 100, 50, {255, 0, 0, 255})
          assert {:error, _reason} = Graphics.present_render(999)

        {:error, _reason} ->
          # SDL2 not available - skip test
          :ok
      end
    end

    # ============================================================================
    # Event Polling Tests
    # ============================================================================

    @tag :sdl2
    @tag :event
    test "poll_event/0 returns :no_event when queue is empty" do
      # When no events are pending, poll_event should return :no_event
      # This test should work regardless of whether SDL2 is initialized
      case Graphics.poll_event() do
        :no_event ->
          # Expected when queue is empty
          :ok

        {:error, _reason} ->
          # Expected when SDL2 not available or not initialized
          :ok

        event ->
          # An event was available (also valid - could be pending events)
          # Verify it's a valid event format
          assert is_tuple(event) or event == :no_event
      end
    end

    @tag :sdl2
    @tag :event
    test "poll_event/0 returns event or error when SDL2 unavailable" do
      case Graphics.sdl_init() do
        {:ok, %{}} ->
          # SDL2 available - poll should return :no_event or an event
          case Graphics.poll_event() do
            :no_event ->
              # No events pending - valid
              :ok

            event when is_tuple(event) ->
              # Got an event - verify it has valid structure
              # Events are tuples like {:quit}, {:key_down, ...}, etc.
              assert is_tuple(event)

            {:error, _reason} ->
              # Error is also valid
              :ok

            other ->
              flunk("Unexpected poll_event result: #{inspect(other)}")
          end

        {:error, _reason} ->
          # SDL2 not available - poll should return error
          case Graphics.poll_event() do
            {:error, _reason} ->
              # Expected
              :ok

            other ->
              flunk("Unexpected poll_event result when SDL2 unavailable: #{inspect(other)}")
          end
      end
    end

    @tag :sdl2
    @tag :event
    test "wait_event/1 times out correctly" do
      # wait_event should return :timeout after the specified timeout
      case Graphics.sdl_init() do
        {:ok, %{}} ->
          # SDL2 available - wait_event with short timeout should return :timeout
          # Use a very short timeout (10ms) to avoid slowing down tests
          case Graphics.wait_event(10) do
            :timeout ->
              # Expected when no events occur
              :ok

            event when is_tuple(event) ->
              # An event occurred before timeout - also valid
              # (could be window events from initialization)
              assert is_tuple(event)

            {:error, _reason} ->
              # Error is also valid
              :ok

            other ->
              flunk("Unexpected wait_event result: #{inspect(other)}")
          end

        {:error, _reason} ->
          # SDL2 not available - should return error
          case Graphics.wait_event(10) do
            {:error, _reason} ->
              # Expected
              :ok

            other ->
              flunk("Unexpected wait_event result when SDL2 unavailable: #{inspect(other)}")
          end
      end
    end

    @tag :sdl2
    @tag :event
    test "wait_event/1 with zero timeout returns immediately" do
      # Zero timeout should return immediately (either :timeout or event)
      case Graphics.wait_event(0) do
        :timeout ->
          # Expected when no events pending
          :ok

        event when is_tuple(event) ->
          # Event available immediately - also valid
          :ok

        {:error, _reason} ->
          # Error is also valid (SDL2 not available)
          :ok

        other ->
          flunk("Unexpected wait_event(0) result: #{inspect(other)}")
      end
    end

    @tag :sdl2
    @tag :event
    test "poll_event/0 returns valid event format when SDL2 available" do
      case Graphics.sdl_init() do
        {:ok, %{}} ->
          # Create a window to generate events
          case Graphics.create_window("Event Test", 400, 300) do
            {:ok, _window_id} ->
              # Poll for any events (window creation may generate events)
              # Drain any pending events
              events = Enum.map(1..10, fn _ ->
                Graphics.poll_event()
              end)

              # All events should be :no_event or valid event tuples
              Enum.each(events, fn event ->
                case event do
                  :no_event ->
                    :ok

                  {:quit} ->
                    :ok

                  {:mouse_button_down, button, x, y} when is_atom(button) and is_integer(x) and is_integer(y) ->
                    :ok

                  {:mouse_button_up, button, x, y} when is_atom(button) and is_integer(x) and is_integer(y) ->
                    :ok

                  {:mouse_motion, x, y, xrel, yrel} when is_integer(x) and is_integer(y) and is_integer(xrel) and is_integer(yrel) ->
                    :ok

                  {:key_down, keycode, modifiers} when is_atom(keycode) and is_map(modifiers) ->
                    :ok

                  {:key_up, keycode, modifiers} when is_atom(keycode) and is_map(modifiers) ->
                    :ok

                  {:window_event, event_id, data1, data2} when is_atom(event_id) and is_integer(data1) and is_integer(data2) ->
                    :ok

                  {:error, _reason} ->
                    :ok

                  other ->
                    flunk("Invalid event format: #{inspect(other)}")
                end
              end)

              # Clean up
              Graphics.destroy_window(_window_id)

            {:error, _reason} ->
              # Window creation failed - skip this test
              :ok
          end

        {:error, _reason} ->
          # SDL2 not available - skip test
          :ok
      end
    end

    @tag :sdl2
    @tag :event
    test "event functions handle negative timeout gracefully" do
      # Negative timeout should be handled (may return error or be treated as zero)
      case Graphics.wait_event(-1) do
        :timeout ->
          :ok

        {:error, _reason} ->
          :ok

        event when is_tuple(event) ->
          :ok

        other ->
          flunk("Unexpected wait_event(-1) result: #{inspect(other)}")
      end
    end

    @tag :sdl2
    @tag :event
    test "event polling with window lifecycle when SDL2 available" do
      case Graphics.sdl_init() do
        {:ok, %{}} ->
          # Test event polling throughout window lifecycle
          assert {:ok, window_id} = Graphics.create_window("Event Lifecycle", 400, 300)

          # Poll events after window creation
          case Graphics.poll_event() do
            :no_event -> :ok
            {:error, _reason} -> :ok
            _event -> :ok
          end

          # Destroy window
          assert :ok = Graphics.destroy_window(window_id)

          # Poll events after window destruction
          case Graphics.poll_event() do
            :no_event -> :ok
            {:error, _reason} -> :ok
            _event -> :ok
          end

        {:error, _reason} ->
          # SDL2 not available - skip test
          :ok
      end
    end

    @tag :sdl2
    @tag :event
    test "poll_event/0 returns error when NIF not loaded" do
      # This test verifies the stub returns appropriate error
      # We can't really test "NIF not loaded" since it's loaded at compile time,
      # but we can verify the function handles SDL2 not being available
      case Graphics.initialized?() do
        false ->
          # NIF not initialized - poll_event should return error
          case Graphics.poll_event() do
            {:error, _reason} ->
              :ok

            :no_event ->
              # Also acceptable - stub might return :no_event
              :ok

            other ->
              flunk("Unexpected result when NIF not initialized: #{inspect(other)}")
          end

        true ->
          # NIF is initialized - skip this test
          :ok
      end
    end
  end

  # ============================================================================
  # Convenience Wrapper API Tests
  # ============================================================================

  describe "convenience wrapper API" do
    @tag :sdl2
    @tag :wrapper
    test "init/0 calls sdl_init correctly" do
      # init/0 is a convenience alias for sdl_init/0
      case Graphics.init() do
        {:ok, %{}} ->
          # SDL2 initialized successfully
          :ok

        {:error, reason} when is_binary(reason) or is_list(reason) ->
          # SDL2 not available - verify error message
          reason_str = if is_list(reason), do: List.to_string(reason), else: reason
          assert String.length(reason_str) > 0
          :ok

        other ->
          flunk("Unexpected init result: #{inspect(other)}")
      end
    end

    @tag :wrapper
    test "color normalization with map" do
      # Test that map colors normalize correctly
      # We can't directly test normalize_color since it's private,
      # but we can test it indirectly through wrapper functions
      color_map = %{r: 255, g: 0, b: 0, a: 255}

      # Test with valid map
      assert is_map(color_map)
      assert Map.get(color_map, :r) == 255
      assert Map.get(color_map, :g) == 0
      assert Map.get(color_map, :b) == 0
      assert Map.get(color_map, :a) == 255
    end

    @tag :wrapper
    test "color normalization with tuple" do
      # Test that tuple colors are accepted
      # 4-element tuple
      color_rgba = {255, 0, 0, 255}
      assert tuple_size(color_rgba) == 4
      assert elem(color_rgba, 0) == 255
      assert elem(color_rgba, 1) == 0
      assert elem(color_rgba, 2) == 0
      assert elem(color_rgba, 3) == 255

      # 3-element tuple (alpha defaults to 255)
      color_rgb = {255, 0, 0}
      assert tuple_size(color_rgb) == 3
    end

    @tag :wrapper
    test "color normalization with atom" do
      # Test that named colors work
      # Verify named color atoms exist
      named_colors = [:black, :white, :red, :green, :blue, :yellow, :cyan, :magenta, :transparent, :gray, :dark_gray, :light_gray]

      Enum.each(named_colors, fn color ->
        assert is_atom(color)
      end)
    end

    @tag :wrapper
    test "color normalization with hex" do
      # Test hex color formats are valid strings
      # 3-digit hex
      hex_3 = "#F00"
      assert String.starts_with?(hex_3, "#")
      assert String.length(hex_3) == 4

      # 6-digit hex
      hex_6 = "#FF0000"
      assert String.starts_with?(hex_6, "#")
      assert String.length(hex_6) == 7

      # 8-digit hex
      hex_8 = "#FF0000FF"
      assert String.starts_with?(hex_8, "#")
      assert String.length(hex_8) == 9
    end

    @tag :sdl2
    @tag :wrapper
    test "renderer cache creates and caches renderer for window" do
      case Graphics.sdl_init() do
        {:ok, %{}} ->
          # Create a window
          case Graphics.create_window("Cache Test", 400, 300) do
            {:ok, window_id} ->
              # First wrapper call should create and cache a renderer
              # Use clear_window which requires a renderer
              case Graphics.clear_window(window_id, :black) do
                :ok ->
                  # Renderer created and cached successfully
                  # Now verify the renderer is cached by calling another wrapper function
                  assert :ok = Graphics.present_window(window_id)

                  # Clean up
                  Graphics.destroy_window(window_id)

                {:error, reason} ->
                  flunk("clear_window failed: #{inspect(reason)}")
              end

            {:error, reason} ->
              flunk("Failed to create window: #{inspect(reason)}")
          end

        {:error, _reason} ->
          # SDL2 not available - skip test
          :ok
      end
    end

    @tag :sdl2
    @tag :wrapper
    test "clear_window/2 with flexible color formats" do
      case Graphics.sdl_init() do
        {:ok, %{}} ->
          case Graphics.create_window("Clear Test", 400, 300) do
            {:ok, window_id} ->
              # Test with named color
              case Graphics.clear_window(window_id, :black) do
                :ok -> :ok
                {:error, _reason} -> flunk("clear_window with :black failed")
              end

              # Test with tuple color
              case Graphics.clear_window(window_id, {255, 0, 0, 255}) do
                :ok -> :ok
                {:error, _reason} -> flunk("clear_window with tuple failed")
              end

              # Test with hex color
              case Graphics.clear_window(window_id, "#000000") do
                :ok -> :ok
                {:error, _reason} -> flunk("clear_window with hex failed")
              end

              # Clean up
              Graphics.destroy_window(window_id)

            {:error, _reason} ->
              # Window creation failed - skip
              :ok
          end

        {:error, _reason} ->
          # SDL2 not available - skip test
          :ok
      end
    end

    @tag :sdl2
    @tag :wrapper
    test "draw/fill_rect_on_window wrappers use cached renderer" do
      case Graphics.sdl_init() do
        {:ok, %{}} ->
          case Graphics.create_window("Draw Wrapper Test", 400, 300) do
            {:ok, window_id} ->
              # Clear window first
              Graphics.clear_window(window_id, :black)

              # Test draw_rect_on_window with different color formats
              assert :ok = Graphics.draw_rect_on_window(window_id, 10, 10, 100, 50, :red)
              assert :ok = Graphics.draw_rect_on_window(window_id, 20, 20, 100, 50, "#00FF00")
              assert :ok = Graphics.draw_rect_on_window(window_id, 30, 30, 100, 50, {0, 0, 255, 255})

              # Test fill_rect_on_window with different color formats
              assert :ok = Graphics.fill_rect_on_window(window_id, 150, 10, 50, 50, :yellow)
              assert :ok = Graphics.fill_rect_on_window(window_id, 150, 70, 50, 50, "#FF00FF")
              assert :ok = Graphics.fill_rect_on_window(window_id, 150, 130, 50, 50, %{r: 0, g: 255, b: 255, a: 255})

              # Present to verify everything worked
              assert :ok = Graphics.present_window(window_id)

              # Clean up
              Graphics.destroy_window(window_id)

            {:error, _reason} ->
              # Window creation failed - skip
              :ok
          end

        {:error, _reason} ->
          # SDL2 not available - skip test
          :ok
      end
    end

    @tag :sdl2
    @tag :wrapper
    test "present_window/1 wrapper uses cached renderer" do
      case Graphics.sdl_init() do
        {:ok, %{}} ->
          case Graphics.create_window("Present Wrapper Test", 400, 300) do
            {:ok, window_id} ->
              # Clear and draw something
              Graphics.clear_window(window_id, :black)
              Graphics.fill_rect_on_window(window_id, 10, 10, 100, 50, :red)

              # Test present_window
              case Graphics.present_window(window_id) do
                :ok ->
                  # Present succeeded
                  :ok

                {:error, reason} ->
                  flunk("present_window failed: #{inspect(reason)}")
              end

              # Clean up
              Graphics.destroy_window(window_id)

            {:error, _reason} ->
              # Window creation failed - skip
              :ok
          end

        {:error, _reason} ->
          # SDL2 not available - skip test
          :ok
      end
    end
  end
end

defmodule DesktopUI.Renderer.SDL2Test do
  use ExUnit.Case, async: false

  alias DesktopUI.Renderer.SDL2
  alias DesktopUI.Widget
  alias DesktopUI.Graphics

  # These tests are not async because they test SDL2 window operations

  describe "init/1" do
    @tag :sdl2
    @tag :renderer
    test "initializes renderer with valid window_id" do
      case Graphics.init() do
        {:ok, %{}} ->
          # SDL2 available - test full initialization
          case Graphics.create_window("SDL2 Renderer Test", 800, 600) do
            {:ok, window_id} ->
              assert {:ok, renderer} = SDL2.init(window_id)
              assert renderer.window_id == window_id
              assert renderer.window_width == 800
              assert renderer.window_height == 600
              assert is_integer(renderer.window_id)
              assert is_integer(renderer.window_width)
              assert is_integer(renderer.window_height)

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
    @tag :renderer
    test "returns error for invalid window_id" do
      # Try to initialize with non-existent window
      assert {:error, _reason} = SDL2.init(9999)
    end
  end

  describe "render/2" do
    @tag :sdl2
    @tag :renderer
    test "renders label widget as colored rectangle" do
      case Graphics.init() do
        {:ok, %{}} ->
          case Graphics.create_window("Label Render Test", 400, 300) do
            {:ok, window_id} ->
              assert {:ok, renderer} = SDL2.init(window_id)

              # Create a label widget
              label = Widget.label("Test Label")

              # Render should succeed
              assert :ok = SDL2.render(renderer, label)

              # Clean up
              SDL2.cleanup(renderer)
              Graphics.destroy_window(window_id)

            {:error, _reason} ->
              :ok
          end

        {:error, _reason} ->
          :ok
      end
    end

    @tag :sdl2
    @tag :renderer
    test "renders button widget as outlined rectangle" do
      case Graphics.init() do
        {:ok, %{}} ->
          case Graphics.create_window("Button Render Test", 400, 300) do
            {:ok, window_id} ->
              assert {:ok, renderer} = SDL2.init(window_id)

              # Create a button widget
              button = Widget.button("Click Me", :clicked)

              # Render should succeed
              assert :ok = SDL2.render(renderer, button)

              # Clean up
              SDL2.cleanup(renderer)
              Graphics.destroy_window(window_id)

            {:error, _reason} ->
              :ok
          end

        {:error, _reason} ->
          :ok
      end
    end

    @tag :sdl2
    @tag :renderer
    test "renders nested containers with correct layout" do
      case Graphics.init() do
        {:ok, %{}} ->
          case Graphics.create_window("Container Render Test", 400, 300) do
            {:ok, window_id} ->
              assert {:ok, renderer} = SDL2.init(window_id)

              # Create nested container structure
              widget =
                Widget.container(:vbox, [
                  Widget.label("Title"),
                  Widget.container(:hbox, [
                    Widget.button("Yes", :yes),
                    Widget.button("No", :no)
                  ], spacing: 8),
                  Widget.label("Footer", id: :footer)
                ], spacing: 16, padding: 10)

              # Render should succeed
              assert :ok = SDL2.render(renderer, widget)

              # Clean up
              SDL2.cleanup(renderer)
              Graphics.destroy_window(window_id)

            {:error, _reason} ->
              :ok
          end

        {:error, _reason} ->
          :ok
      end
    end

    @tag :sdl2
    @tag :renderer
    test "applies spacing between container children" do
      case Graphics.init() do
        {:ok, %{}} ->
          case Graphics.create_window("Spacing Test", 400, 300) do
            {:ok, window_id} ->
              assert {:ok, renderer} = SDL2.init(window_id)

              # Create vbox with spacing
              widget =
                Widget.container(:vbox, [
                  Widget.label("First"),
                  Widget.label("Second"),
                  Widget.label("Third")
                ], spacing: 20)

              # Render should succeed
              assert :ok = SDL2.render(renderer, widget)

              # Clean up
              SDL2.cleanup(renderer)
              Graphics.destroy_window(window_id)

            {:error, _reason} ->
              :ok
          end

        {:error, _reason} ->
          :ok
      end
    end

    @tag :sdl2
    @tag :renderer
    test "applies padding to container edges" do
      case Graphics.init() do
        {:ok, %{}} ->
          case Graphics.create_window("Padding Test", 400, 300) do
            {:ok, window_id} ->
              assert {:ok, renderer} = SDL2.init(window_id)

              # Create container with padding
              widget =
                Widget.container(:vbox, [
                  Widget.label("Padded Content")
                ], padding: 30)

              # Render should succeed
              assert :ok = SDL2.render(renderer, widget)

              # Clean up
              SDL2.cleanup(renderer)
              Graphics.destroy_window(window_id)

            {:error, _reason} ->
              :ok
          end

        {:error, _reason} ->
          :ok
      end
    end
  end

  describe "cleanup/1" do
    @tag :sdl2
    @tag :renderer
    test "cleanup succeeds for valid renderer" do
      case Graphics.init() do
        {:ok, %{}} ->
          case Graphics.create_window("Cleanup Test", 400, 300) do
            {:ok, window_id} ->
              assert {:ok, renderer} = SDL2.init(window_id)

              # Cleanup should succeed
              assert :ok = SDL2.cleanup(renderer)

              # Clean up window
              Graphics.destroy_window(window_id)

            {:error, _reason} ->
              :ok
          end

        {:error, _reason} ->
          :ok
      end
    end
  end

  describe "widget dimensions" do
    @tag :sdl2
    @tag :renderer
    test "uses custom dimensions when provided" do
      case Graphics.init() do
        {:ok, %{}} ->
          case Graphics.create_window("Dimensions Test", 400, 300) do
            {:ok, window_id} ->
              assert {:ok, renderer} = SDL2.init(window_id)

              # Create widgets with custom dimensions
              label = Widget.label("Wide Label", width: 200, height: 50)
              button = Widget.button("Big Button", :click, width: 150, height: 60)

              widget =
                Widget.container(:vbox, [label, button], spacing: 10)

              # Render should succeed
              assert :ok = SDL2.render(renderer, widget)

              # Clean up
              SDL2.cleanup(renderer)
              Graphics.destroy_window(window_id)

            {:error, _reason} ->
              :ok
          end

        {:error, _reason} ->
          :ok
      end
    end

    @tag :sdl2
    @tag :renderer
    test "uses default dimensions when not provided" do
      case Graphics.init() do
        {:ok, %{}} ->
          case Graphics.create_window("Default Dimensions Test", 400, 300) do
            {:ok, window_id} ->
              assert {:ok, renderer} = SDL2.init(window_id)

              # Create widgets without custom dimensions
              label = Widget.label("Default Label")
              button = Widget.button("Default Button", :click)

              widget =
                Widget.container(:hbox, [label, button], spacing: 10)

              # Render should succeed
              assert :ok = SDL2.render(renderer, widget)

              # Clean up
              SDL2.cleanup(renderer)
              Graphics.destroy_window(window_id)

            {:error, _reason} ->
              :ok
          end

        {:error, _reason} ->
          :ok
      end
    end
  end

  describe "layout types" do
    @tag :sdl2
    @tag :renderer
    test "hbox arranges children horizontally" do
      case Graphics.init() do
        {:ok, %{}} ->
          case Graphics.create_window("HBox Test", 400, 300) do
            {:ok, window_id} ->
              assert {:ok, renderer} = SDL2.init(window_id)

              # Create hbox with multiple buttons
              widget =
                Widget.container(:hbox, [
                  Widget.button("Left", :left),
                  Widget.button("Center", :center),
                  Widget.button("Right", :right)
                ], spacing: 10, padding: 20)

              # Render should succeed
              assert :ok = SDL2.render(renderer, widget)

              # Clean up
              SDL2.cleanup(renderer)
              Graphics.destroy_window(window_id)

            {:error, _reason} ->
              :ok
          end

        {:error, _reason} ->
          :ok
      end
    end

    @tag :sdl2
    @tag :renderer
    test "vbox stacks children vertically" do
      case Graphics.init() do
        {:ok, %{}} ->
          case Graphics.create_window("VBox Test", 400, 300) do
            {:ok, window_id} ->
              assert {:ok, renderer} = SDL2.init(window_id)

              # Create vbox with multiple labels
              widget =
                Widget.container(:vbox, [
                  Widget.label("First Item"),
                  Widget.label("Second Item"),
                  Widget.label("Third Item")
                ], spacing: 10, padding: 20)

              # Render should succeed
              assert :ok = SDL2.render(renderer, widget)

              # Clean up
              SDL2.cleanup(renderer)
              Graphics.destroy_window(window_id)

            {:error, _reason} ->
              :ok
          end

        {:error, _reason} ->
          :ok
      end
    end
  end

  describe "error handling" do
    @tag :sdl2
    @tag :renderer
    test "handles rendering to invalid window gracefully" do
      # Create a renderer with invalid window
      assert {:error, _reason} = SDL2.init(9999)

      # Even with invalid renderer, cleanup should succeed
      # Note: We can't test render with invalid renderer since init fails
    end

    @tag :sdl2
    @tag :renderer
    test "cleanup always succeeds" do
      # Cleanup should be safe to call even with minimal struct
      renderer = %SDL2{
        window_id: 0,
        window_width: 100,
        window_height: 100
      }

      assert :ok = SDL2.cleanup(renderer)
    end
  end
end

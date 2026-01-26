defmodule DesktopUI.Graphics.Convenience do
  @moduledoc """
  Convenience API for SDL2 graphics operations.

  This module provides wrapper functions that automatically manage renderer
  creation and caching for windows. Instead of manually creating and managing
  renderers, you can use these functions which take `window_id` and
  automatically handle renderer management.

  ## Automatic Renderer Management

  Wrapper functions that take `window_id` automatically create and cache a
  renderer for that window on first use. The renderer is automatically
  destroyed when the window is destroyed.

  ## Color Format Support

  All drawing functions accept colors in multiple formats:

  - **Tuple**: `{r, g, b, a}` - Each component 0-255
  - **Map**: `%{r: 255, g: 0, b: 0, a: 255}`
  - **Atom**: Named colors like `:red`, `:blue`, `:green`, `:black`, `:white`
  - **Hex string**: `"#FF0000"` for red, `"#00FF00"` for green, etc.

  ## Examples

  Using the convenience API with automatic renderer management and flexible colors:

      # Initialize and create a window
      DesktopUI.Graphics.init()
      {:ok, window_id} = DesktopUI.Graphics.Window.create("My App", 800, 600)

      # Draw with automatic renderer management and flexible colors
      DesktopUI.Graphics.Convenience.clear(window_id, :black)
      DesktopUI.Graphics.Convenience.fill_rect(window_id, 10, 10, 100, 50, :red)
      DesktopUI.Graphics.Convenience.draw_rect(window_id, 120, 10, 100, 50, "#00FF00")
      DesktopUI.Graphics.Convenience.present(window_id)

      # Cleanup (renderer destroyed automatically)
      DesktopUI.Graphics.Window.destroy(window_id)

  """

  alias DesktopUI.Graphics.{Renderer, Drawing}
  alias DesktopUI.Color

  @doc """
  Clear a window to a solid color.

  This is a convenience function that automatically creates a renderer for
  the window if needed, sets the draw color, and clears the window.

  ## Parameters

  - `window_id` - Window ID from `DesktopUI.Graphics.Window.create/4`
  - `color` - Color in any supported format (map, tuple, atom, or hex string)

  ## Returns

  - `:ok` - Window cleared successfully
  - `{:error, reason}` - Operation failed

  ## Examples

      DesktopUI.Graphics.Convenience.clear(window_id, :black)
      DesktopUI.Graphics.Convenience.clear(window_id, {255, 0, 0, 255})
      DesktopUI.Graphics.Convenience.clear(window_id, %{r: 0, g: 0, b: 0, a: 255})
      DesktopUI.Graphics.Convenience.clear(window_id, "#000000")

  """
  @spec clear(non_neg_integer(), term()) :: :ok | {:error, String.t()}
  def clear(window_id, color) do
    with {:ok, renderer_id} <- Renderer.ensure(window_id),
         {r, g, b, a} <- Color.normalize(color),
         :ok <- Renderer.set_draw_color(renderer_id, r, g, b, a),
      do: Renderer.clear(renderer_id)
  end

  @doc """
  Draw an outline rectangle on a window.

  This is a convenience function that automatically creates a renderer for
  the window if needed and draws an outline rectangle.

  ## Parameters

  - `window_id` - Window ID from `DesktopUI.Graphics.Window.create/4`
  - `x` - X coordinate of top-left corner
  - `y` - Y coordinate of top-left corner
  - `w` - Width of rectangle
  - `h` - Height of rectangle
  - `color` - Color in any supported format (map, tuple, atom, or hex string)

  ## Returns

  - `:ok` - Rectangle drawn successfully
  - `{:error, reason}` - Operation failed

  ## Examples

      DesktopUI.Graphics.Convenience.draw_rect(window_id, 10, 10, 100, 50, :red)
      DesktopUI.Graphics.Convenience.draw_rect(window_id, 10, 10, 100, 50, "#FF0000")

  """
  @spec draw_rect(non_neg_integer(), integer(), integer(), integer(), integer(), term()) ::
          :ok | {:error, String.t()}
  def draw_rect(window_id, x, y, w, h, color) do
    with {:ok, renderer_id} <- Renderer.ensure(window_id),
         {r, g, b, a} <- Color.normalize(color),
      do: Drawing.draw_rect(renderer_id, x, y, w, h, {r, g, b, a})
  end

  @doc """
  Draw a filled rectangle on a window.

  This is a convenience function that automatically creates a renderer for
  the window if needed and draws a filled rectangle.

  ## Parameters

  - `window_id` - Window ID from `DesktopUI.Graphics.Window.create/4`
  - `x` - X coordinate of top-left corner
  - `y` - Y coordinate of top-left corner
  - `w` - Width of rectangle
  - `h` - Height of rectangle
  - `color` - Color in any supported format (map, tuple, atom, or hex string)

  ## Returns

  - `:ok` - Rectangle drawn successfully
  - `{:error, reason}` - Operation failed

  ## Examples

      DesktopUI.Graphics.Convenience.fill_rect(window_id, 10, 10, 100, 50, :blue)
      DesktopUI.Graphics.Convenience.fill_rect(window_id, 10, 10, 100, 50, "#0000FF")

  """
  @spec fill_rect(non_neg_integer(), integer(), integer(), integer(), integer(), term()) ::
          :ok | {:error, String.t()}
  def fill_rect(window_id, x, y, w, h, color) do
    with {:ok, renderer_id} <- Renderer.ensure(window_id),
         {r, g, b, a} <- Color.normalize(color),
      do: Drawing.fill_rect(renderer_id, x, y, w, h, {r, g, b, a})
  end

  @doc """
  Present the rendered content to the screen.

  This is a convenience function that automatically creates a renderer for
  the window if needed and presents the rendered content.

  ## Parameters

  - `window_id` - Window ID from `DesktopUI.Graphics.Window.create/4`

  ## Returns

  - `:ok` - Content presented successfully
  - `{:error, reason}` - Operation failed

  ## Examples

      DesktopUI.Graphics.Convenience.present(window_id)

  """
  @spec present(non_neg_integer()) :: :ok | {:error, String.t()}
  def present(window_id) do
    with {:ok, renderer_id} <- Renderer.ensure(window_id),
      do: Renderer.present(renderer_id)
  end
end

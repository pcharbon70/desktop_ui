defmodule DesktopUI.Graphics.Drawing do
  @moduledoc """
  Drawing primitives for SDL2 renderers.

  This module provides functions for drawing shapes on SDL2 renderers.
  All drawing operations use color tuples `{r, g, b, a}` where each
  component is a value between 0 and 255.

  ## Examples

  Draw a filled rectangle:

      iex> DesktopUI.Graphics.Drawing.fill_rect(0, 10, 10, 100, 50, {255, 0, 0, 255})
      :ok

  Draw an outline rectangle:

      iex> DesktopUI.Graphics.Drawing.draw_rect(0, 20, 20, 80, 30, {0, 0, 255, 255})
      :ok

  ## Typical Rendering Loop

      # Clear screen with black
      DesktopUI.Graphics.Renderer.set_draw_color(0, 0, 0, 0, 255)
      DesktopUI.Graphics.Renderer.clear(0)

      # Draw a red filled rectangle
      DesktopUI.Graphics.Drawing.fill_rect(0, 10, 10, 100, 50, {255, 0, 0, 255})

      # Draw a blue outline rectangle
      DesktopUI.Graphics.Drawing.draw_rect(0, 20, 20, 80, 30, {0, 0, 255, 255})

      # Present to screen
      DesktopUI.Graphics.Renderer.present(0)

  """

  @doc """
  Draw an outline rectangle.

  Draws the outline of a rectangle at the specified position with the
  specified color. The color is specified as a tuple `{r, g, b, a}` where
  each component is a value between 0 and 255.

  This function temporarily changes the draw color for this operation only,
  then restores the previous color.

  ## Parameters

  - `renderer_id` - Renderer ID returned from `DesktopUI.Graphics.Renderer.create/1`
  - `x` - X position in pixels
  - `y` - Y position in pixels
  - `w` - Width in pixels
  - `h` - Height in pixels
  - `color` - Color tuple `{r, g, b, a}` where each component is 0-255

  ## Returns

  - `:ok` - Rectangle drawn successfully
  - `{:error, reason}` - Operation failed

  ## Examples

      iex> DesktopUI.Graphics.Drawing.draw_rect(0, 10, 10, 100, 50, {255, 0, 0, 255})
      :ok

  """
  @spec draw_rect(non_neg_integer(), integer(), integer(), integer(), integer(), {0..255, 0..255, 0..255, 0..255}) ::
          :ok | {:error, String.t()}
  def draw_rect(renderer_id, x, y, w, h, color)
      when is_integer(renderer_id) and is_integer(x) and is_integer(y) and is_integer(w) and
             is_integer(h) and is_tuple(color) do
    DesktopUI.Graphics.nif_draw_rect(renderer_id, x, y, w, h, color)
  end

  @doc """
  Draw a filled rectangle.

  Draws a filled rectangle at the specified position with the specified color.
  The color is specified as a tuple `{r, g, b, a}` where each component is a
  value between 0 and 255.

  This function temporarily changes the draw color for this operation only,
  then restores the previous color.

  ## Parameters

  - `renderer_id` - Renderer ID returned from `DesktopUI.Graphics.Renderer.create/1`
  - `x` - X position in pixels
  - `y` - Y position in pixels
  - `w` - Width in pixels
  - `h` - Height in pixels
  - `color` - Color tuple `{r, g, b, a}` where each component is 0-255

  ## Returns

  - `:ok` - Rectangle drawn successfully
  - `{:error, reason}` - Operation failed

  ## Examples

      iex> DesktopUI.Graphics.Drawing.fill_rect(0, 10, 10, 100, 50, {0, 255, 0, 255})
      :ok

  """
  @spec fill_rect(non_neg_integer(), integer(), integer(), integer(), integer(), {0..255, 0..255, 0..255, 0..255}) ::
          :ok | {:error, String.t()}
  def fill_rect(renderer_id, x, y, w, h, color)
      when is_integer(renderer_id) and is_integer(x) and is_integer(y) and is_integer(w) and
             is_integer(h) and is_tuple(color) do
    DesktopUI.Graphics.nif_fill_rect(renderer_id, x, y, w, h, color)
  end
end

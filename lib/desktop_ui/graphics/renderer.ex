defmodule DesktopUI.Graphics.Renderer do
  @moduledoc """
  Renderer management operations for SDL2.

  This module provides functions for creating and managing SDL2 renderers.
  A renderer handles drawing operations for a window. Each window can have
  at most one renderer. The renderer is created with hardware acceleration
  and vsync enabled for smooth rendering.

  ## Examples

  Create a renderer:

      iex> DesktopUI.Graphics.Renderer.create(0)
      {:ok, 0}

  Set draw color:

      iex> DesktopUI.Graphics.Renderer.set_draw_color(0, 255, 0, 0, 255)
      :ok

  Clear renderer:

      iex> DesktopUI.Graphics.Renderer.clear(0)
      :ok

  Present to screen:

      iex> DesktopUI.Graphics.Renderer.present(0)
      :ok

  Destroy renderer:

      iex> DesktopUI.Graphics.Renderer.destroy(0)
      :ok

  ## Typical Rendering Loop

      # Clear screen with black
      DesktopUI.Graphics.Renderer.set_draw_color(0, 0, 0, 0, 255)
      DesktopUI.Graphics.Renderer.clear(0)

      # Draw shapes
      DesktopUI.Graphics.Drawing.fill_rect(0, 10, 10, 100, 50, {255, 0, 0, 255})

      # Present to screen
      DesktopUI.Graphics.Renderer.present(0)

  """

  @doc """
  Create a new SDL2 renderer for a window.

  A renderer handles drawing operations for a window. Each window can have
  at most one renderer. The renderer is created with hardware acceleration
  and vsync enabled for smooth rendering.

  ## Parameters

  - `window_id` - Window ID returned from `DesktopUI.Graphics.Window.create/4`

  ## Returns

  - `{:ok, renderer_id}` - Renderer created successfully
  - `{:error, reason}` - Renderer creation failed

  ## Examples

      iex> DesktopUI.Graphics.Renderer.create(0)
      {:ok, 0}

  """
  @spec create(non_neg_integer()) :: {:ok, non_neg_integer()} | {:error, String.t()}
  def create(window_id) when is_integer(window_id) do
    DesktopUI.Graphics.nif_create_renderer(window_id)
  end

  @doc """
  Destroy an SDL2 renderer and release its resources.

  ## Parameters

  - `renderer_id` - Renderer ID returned from `create/1`

  ## Returns

  - `:ok` - Renderer destroyed successfully
  - `{:error, reason}` - Renderer destruction failed

  ## Examples

      iex> DesktopUI.Graphics.Renderer.destroy(0)
      :ok

  """
  @spec destroy(non_neg_integer()) :: :ok | {:error, String.t()}
  def destroy(renderer_id) when is_integer(renderer_id) do
    DesktopUI.Graphics.nif_destroy_renderer(renderer_id)
  end

  @doc """
  Set the draw color for a renderer.

  This sets the color that will be used for drawing operations like
  `clear/1`, `DesktopUI.Graphics.Drawing.draw_rect/6`, and
  `DesktopUI.Graphics.Drawing.fill_rect/6`. Each component should be
  a value between 0 and 255.

  ## Parameters

  - `renderer_id` - Renderer ID returned from `create/1`
  - `r` - Red component (0-255)
  - `g` - Green component (0-255)
  - `b` - Blue component (0-255)
  - `a` - Alpha component (0-255, 255 = fully opaque)

  ## Returns

  - `:ok` - Draw color set successfully
  - `{:error, reason}` - Operation failed

  ## Examples

      iex> DesktopUI.Graphics.Renderer.set_draw_color(0, 255, 0, 0, 255)
      :ok

  """
  @spec set_draw_color(non_neg_integer(), 0..255, 0..255, 0..255, 0..255) ::
          :ok | {:error, String.t()}
  def set_draw_color(renderer_id, r, g, b, a)
      when is_integer(renderer_id) and is_integer(r) and is_integer(g) and is_integer(b) and
             is_integer(a) do
    DesktopUI.Graphics.nif_set_render_draw_color(renderer_id, r, g, b, a)
  end

  @doc """
  Clear the renderer target with the current draw color.

  This fills the entire render target with the color set by
  `set_draw_color/5`.

  ## Parameters

  - `renderer_id` - Renderer ID returned from `create/1`

  ## Returns

  - `:ok` - Renderer cleared successfully
  - `{:error, reason}` - Operation failed

  ## Examples

      iex> DesktopUI.Graphics.Renderer.set_draw_color(0, 0, 0, 0, 255)
      :ok
      iex> DesktopUI.Graphics.Renderer.clear(0)
      :ok

  """
  @spec clear(non_neg_integer()) :: :ok | {:error, String.t()}
  def clear(renderer_id) when is_integer(renderer_id) do
    DesktopUI.Graphics.nif_clear_render(renderer_id)
  end

  @doc """
  Present the rendered content to the screen.

  This swaps the buffers to display what has been rendered since the last
  call to `present/1`. You must call this function after drawing
  operations to make them visible on screen.

  ## Parameters

  - `renderer_id` - Renderer ID returned from `create/1`

  ## Returns

  - `:ok` - Content presented successfully
  - `{:error, reason}` - Operation failed

  ## Examples

      iex> DesktopUI.Graphics.Renderer.present(0)
      :ok

  ## Typical Rendering Loop

      # Clear screen with black
      DesktopUI.Graphics.Renderer.set_draw_color(0, 0, 0, 0, 255)
      DesktopUI.Graphics.Renderer.clear(0)

      # Draw a red rectangle
      DesktopUI.Graphics.Drawing.fill_rect(0, 10, 10, 100, 50, {255, 0, 0, 255})

      # Present to screen
      DesktopUI.Graphics.Renderer.present(0)

  """
  @spec present(non_neg_integer()) :: :ok | {:error, String.t()}
  def present(renderer_id) when is_integer(renderer_id) do
    DesktopUI.Graphics.nif_present_render(renderer_id)
  end

  @doc """
  Ensure a renderer exists for the given window.

  Returns the cached renderer if available, or creates a new one.

  ## Parameters

  - `window_id` - Window ID

  ## Returns

  - `{:ok, renderer_id}` - Renderer available (cached or newly created)
  - `{:error, reason}` - Failed to get or create renderer

  ## Examples

      iex> DesktopUI.Graphics.Renderer.ensure(0)
      {:ok, 0}

  """
  @spec ensure(non_neg_integer()) :: {:ok, non_neg_integer()} | {:error, String.t()}
  def ensure(window_id) do
    case get_renderer_for_window(window_id) do
      {:ok, renderer_id} ->
        {:ok, renderer_id}

      :error ->
        with {:ok, renderer_id} <- create(window_id),
             :ok <- cache_renderer(window_id, renderer_id) do
          {:ok, renderer_id}
        end
    end
  end

  # Get the cached renderer for a window.
  defp get_renderer_for_window(window_id) do
    case DesktopUI.RendererCache.get_renderer(window_id) do
      {:ok, renderer_id} -> {:ok, renderer_id}
      {:error, _reason} -> :error
    end
  end

  # Cache the renderer association for a window.
  defp cache_renderer(window_id, renderer_id) do
    DesktopUI.RendererCache.put_renderer(window_id, renderer_id)
  end
end

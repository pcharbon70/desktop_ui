defmodule DesktopUI.Graphics.Window do
  @moduledoc """
  Window management operations for SDL2.

  This module provides high-level functions for creating and managing SDL2 windows.
  Windows are identified by integer IDs returned from `create/4`.

  ## Examples

  Create a window:

      iex> DesktopUI.Graphics.sdl_init()
      {:ok, %{}}
      iex> DesktopUI.Graphics.Window.create("My Window", 800, 600)
      {:ok, 0}

  Create a window with options:

      iex> DesktopUI.Graphics.Window.create("Fixed Window", 640, 480, resizable: false)
      {:ok, 1}

  Get window size:

      iex> DesktopUI.Graphics.Window.get_size(0)
      {:ok, {800, 600}}

  Resize window:

      iex> DesktopUI.Graphics.Window.set_size(0, 1024, 768)
      :ok

  Set window title:

      iex> DesktopUI.Graphics.Window.set_title(0, "New Title")
      :ok

  Destroy window:

      iex> DesktopUI.Graphics.Window.destroy(0)
      :ok

  """

  @doc """
  Create a new SDL2 window.

  ## Parameters

  - `title` - Window title
  - `width` - Window width in pixels (positive integer, max 8191)
  - `height` - Window height in pixels (positive integer, max 8191)
  - `opts` - Optional keyword list:
    - `:resizable` - Allow window to be resized (default: true)
    - `:fullscreen` - Create fullscreen window (default: false)
    - `:hidden` - Create window initially hidden (default: false)
    - `:borderless` - Create window without borders (default: false)

  ## Returns

  - `{:ok, window_id}` - Window created successfully
  - `{:error, reason}` - Window creation failed

  ## Examples

      iex> DesktopUI.Graphics.Window.create("My Window", 800, 600)
      {:ok, 0}

      iex> DesktopUI.Graphics.Window.create("Fixed", 640, 480, resizable: false)
      {:ok, 1}

  """
  @spec create(String.t(), pos_integer(), pos_integer(), keyword()) ::
          {:ok, non_neg_integer()} | {:error, String.t()}
  def create(title, width, height, opts \\ []) do
    flags = parse_window_flags(opts)
    DesktopUI.Graphics.nif_create_window(title, width, height, flags)
  end

  @doc """
  Destroy an SDL2 window and release its resources.

  Also destroys any cached renderer associated with the window.

  ## Parameters

  - `window_id` - Window ID returned from `create/4`

  ## Returns

  - `:ok` - Window destroyed successfully
  - `{:error, reason}` - Window destruction failed

  ## Examples

      iex> DesktopUI.Graphics.Window.destroy(0)
      :ok

  """
  @spec destroy(non_neg_integer()) :: :ok | {:error, String.t()}
  def destroy(window_id) when is_integer(window_id) do
    # Cleanup renderer cache first (auto-destroys renderer)
    remove_renderer_cache(window_id)
    # Then destroy the window
    DesktopUI.Graphics.nif_destroy_window(window_id)
  end

  @doc """
  Get the current size of a window.

  ## Parameters

  - `window_id` - Window ID returned from `create/4`

  ## Returns

  - `{:ok, {width, height}}` - Window size in pixels
  - `{:error, reason}` - Failed to get window size

  ## Examples

      iex> DesktopUI.Graphics.Window.get_size(0)
      {:ok, {800, 600}}

  """
  @spec get_size(non_neg_integer()) :: {:ok, {pos_integer(), pos_integer()}} | {:error, String.t()}
  def get_size(window_id) when is_integer(window_id) do
    DesktopUI.Graphics.nif_get_window_size(window_id)
  end

  @doc """
  Resize a window.

  ## Parameters

  - `window_id` - Window ID returned from `create/4`
  - `width` - New width in pixels (positive integer)
  - `height` - New height in pixels (positive integer)

  ## Returns

  - `:ok` - Window resized successfully
  - `{:error, reason}` - Failed to resize window

  ## Examples

      iex> DesktopUI.Graphics.Window.set_size(0, 1024, 768)
      :ok

  """
  @spec set_size(non_neg_integer(), pos_integer(), pos_integer()) :: :ok | {:error, String.t()}
  def set_size(window_id, width, height)
      when is_integer(window_id) and is_integer(width) and is_integer(height) do
    DesktopUI.Graphics.nif_set_window_size(window_id, width, height)
  end

  @doc """
  Set the title of a window.

  ## Parameters

  - `window_id` - Window ID returned from `create/4`
  - `title` - New title for the window

  ## Returns

  - `:ok` - Title updated successfully
  - `{:error, reason}` - Failed to update title

  ## Examples

      iex> DesktopUI.Graphics.Window.set_title(0, "New Title")
      :ok

  """
  @spec set_title(non_neg_integer(), String.t()) :: :ok | {:error, String.t()}
  def set_title(window_id, title) when is_integer(window_id) do
    DesktopUI.Graphics.nif_set_window_title(window_id, title)
  end

  # Parse window options into SDL2 flags
  # SDL_WINDOW_RESIZABLE = 0x00000020
  # SDL_WINDOW_FULLSCREEN = 0x00000001
  # SDL_WINDOW_HIDDEN = 0x00000008
  # SDL_WINDOW_BORDERLESS = 0x00000010
  defp parse_window_flags(opts) do
    import Bitwise

    flags =
      if Keyword.get(opts, :resizable, true), do: 0x00000020, else: 0

    flags =
      if Keyword.get(opts, :fullscreen, false), do: bor(flags, 0x00000001), else: flags

    flags =
      if Keyword.get(opts, :hidden, false), do: bor(flags, 0x00000008), else: flags

    flags =
      if Keyword.get(opts, :borderless, false), do: bor(flags, 0x00000010), else: flags

    flags
  end

  # Remove the renderer cache for a window and destroy the renderer.
  defp remove_renderer_cache(window_id) do
    case get_renderer_for_window(window_id) do
      {:ok, renderer_id} ->
        DesktopUI.RendererCache.delete_renderer(window_id)
        DesktopUI.Graphics.nif_destroy_renderer(renderer_id)

      :error ->
        :ok
    end
  end

  # Get the cached renderer for a window.
  defp get_renderer_for_window(window_id) do
    case DesktopUI.RendererCache.get_renderer(window_id) do
      {:ok, renderer_id} -> {:ok, renderer_id}
      {:error, _reason} -> :error
    end
  end
end

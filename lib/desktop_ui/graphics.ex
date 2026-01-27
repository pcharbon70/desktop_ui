defmodule DesktopUI.Graphics do
  @moduledoc """
  Graphics API for DesktopUI.

  This module provides the native interface to SDL2 graphics operations.
  It loads a NIF (Native Implemented Function) library that wraps SDL2
  functions and makes them callable from Elixir.

  ## Architecture

  ```
  Elixir (DesktopUI.Graphics)
      ↓ loads NIF
  C NIF (desktop_ui_nif.so)
      ↓ links to
  SDL2 Library
  ```

  ## Module Organization

  For better code organization, the Graphics API has been split into focused modules:

  - **`DesktopUI.Graphics`** (this module) - Core NIF wrapper, initialization, and event polling
  - **`DesktopUI.Graphics.Window`** - Window management operations
  - **`DesktopUI.Graphics.Renderer`** - Renderer management operations
  - **`DesktopUI.Graphics.Drawing`** - Drawing primitives
  - **`DesktopUI.Graphics.Convenience`** - High-level convenience API with automatic renderer management

  The old API is fully preserved for backward compatibility. All functions
  that were previously in this module are still available and delegate to
  the appropriate sub-module.

  ## Migration Guide

  The old API continues to work:

      DesktopUI.Graphics.create_window("My Window", 800, 600)
      DesktopUI.Graphics.clear_window(window_id, :black)

  For new code, prefer using the sub-modules directly:

      DesktopUI.Graphics.Window.create("My Window", 800, 600)
      DesktopUI.Graphics.Convenience.clear(window_id, :black)

  ## SDL2 Requirement

  This module requires SDL2 to be installed on your system:

  **Ubuntu/Debian:**
  ```bash
  sudo apt-get install libsdl2-dev
  ```

  **macOS:**
  ```bash
  brew install sdl2
  ```

  ## NIF Loading

  The NIF library is loaded automatically when this module is first accessed.
  If the NIF fails to load, the module will use fallback implementations
  that return helpful error messages.

  ## Examples

  Check if the NIF is loaded:

      iex> DesktopUI.Graphics.initialized?()
      true

  Get version information:

      iex> DesktopUI.Graphics.version()
      "0.3.0-nif"

  Initialize SDL2 and create a window:

      iex> DesktopUI.Graphics.sdl_init()
      {:ok, %{}}
      iex> DesktopUI.Graphics.create_window("My Window", 800, 600)
      {:ok, 0}

  Using the new modular API:

      iex> DesktopUI.Graphics.Window.create("My Window", 800, 600)
      {:ok, 0}
      iex> DesktopUI.Graphics.Convenience.clear(0, :black)
      :ok

  Poll for events:

      iex> DesktopUI.Graphics.poll_event()
      {:quit}

  """

  @doc """
  Get the NIF version string.

  ## Returns

  - `version_string` - Version of the NIF library (e.g., "0.1.0-nif")

  ## Examples

      iex> DesktopUI.Graphics.version()
      "0.1.0-nif"

  """
  @spec version() :: String.t()
  def version do
    nif_get_version()
  end

  @doc """
  Check if the NIF is loaded and initialized.

  ## Returns

  - `true` - NIF is loaded and initialized
  - `false` - NIF is not loaded or initialization failed

  ## Examples

      iex> DesktopUI.Graphics.initialized?()
      true

  """
  @spec initialized?() :: boolean()
  def initialized? do
    result = nif_is_initialized()
    result == "true"
  end

  @doc """
  Initialize the NIF and return version information.

  ## Returns

  - `{:ok, info}` - NIF initialized successfully, info map contains:
    - `:version` - Version string
    - `:initialized` - Initialization status (1 = true)
  - `{:error, reason}` - NIF initialization failed

  ## Examples

      iex> DesktopUI.Graphics.nif_init()
      {:ok, %{version: "0.1.0-nif", initialized: 1}}

  """
  @spec nif_init() :: {:ok, map()} | {:error, String.t()}
  def nif_init do
    case nif_init_nif() do
      {:ok, info} when is_map(info) ->
        {:ok, info}

      {:error, _reason} = error ->
        error

      other ->
        {:error, "Unexpected response from NIF: #{inspect(other)}"}
    end
  end

  @doc """
  Get the last error message from the NIF.

  ## Returns

  - Error message string

  ## Examples

      iex> DesktopUI.Graphics.get_error()
      "No error"

  """
  @spec get_error() :: String.t()
  def get_error do
    nif_get_error()
  end

  # ============================================================================
  # Window Management API
  # ============================================================================

  @doc """
  Initialize the SDL2 video subsystem.

  This must be called before creating any windows. It initializes SDL2
  and prepares it for window creation and graphics operations.

  ## Returns

  - `{:ok, %{}}` - SDL2 initialized successfully
  - `{:error, reason}` - SDL2 initialization failed

  ## Examples

      iex> DesktopUI.Graphics.sdl_init()
      {:ok, %{}}

  """
  @spec sdl_init() :: {:ok, map()} | {:error, String.t()}
  def sdl_init do
    nif_sdl_init()
  end

  @doc """
  Quit SDL2 and clean up resources.

  This should be called when shutting down the application to properly
  clean up SDL2 resources.

  ## Returns

  - `:ok` - SDL2 quit successfully

  ## Examples

      iex> DesktopUI.Graphics.sdl_init()
      {:ok, %{}}
      iex> DesktopUI.Graphics.sdl_quit()
      :ok

  """
  @spec sdl_quit() :: :ok
  def sdl_quit do
    nif_sdl_quit()
  end

  @doc """
  Create a new SDL2 window.

  ## Parameters

  - `title` - Window title (string)
  - `width` - Window width in pixels (positive integer)
  - `height` - Window height in pixels (positive integer)
  - `opts` - Optional keyword list:
    - `:resizable` - Allow window to be resized (default: true)
    - `:fullscreen` - Create window in fullscreen mode (default: false)
    - `:hidden` - Create window hidden (default: false)
    - `:borderless` - Create borderless window (default: false)

  ## Returns

  - `{:ok, window_id}` - Window created successfully, window_id is an integer
  - `{:error, reason}` - Window creation failed

  ## Examples

      iex> DesktopUI.Graphics.sdl_init()
      {:ok, %{}}
      iex> DesktopUI.Graphics.create_window("My Window", 800, 600)
      {:ok, 0}
      iex> DesktopUI.Graphics.create_window("Fixed Window", 640, 480, resizable: false)
      {:ok, 1}

  """
  @spec create_window(String.t(), pos_integer(), pos_integer(), keyword()) ::
          {:ok, non_neg_integer()} | {:error, String.t()}
  def create_window(title, width, height, opts \\ []) do
    flags = parse_window_flags(opts)
    nif_create_window(title, width, height, flags)
  end

  @doc """
  Destroy an SDL2 window and release its resources.

  ## Parameters

  - `window_id` - Window ID returned from `create_window/4`

  ## Returns

  - `:ok` - Window destroyed successfully
  - `{:error, reason}` - Window destruction failed

  ## Examples

      iex> DesktopUI.Graphics.destroy_window(0)
      :ok

  """
  @spec destroy_window(non_neg_integer()) :: :ok | {:error, String.t()}
  def destroy_window(window_id) when is_integer(window_id) do
    # Cleanup renderer cache first (auto-destroys renderer)
    remove_renderer_cache(window_id)
    # Then destroy the window
    nif_destroy_window(window_id)
  end

  @doc """
  Get the current size of a window.

  ## Parameters

  - `window_id` - Window ID returned from `create_window/4`

  ## Returns

  - `{:ok, {width, height}}` - Window size in pixels
  - `{:error, reason}` - Failed to get window size

  ## Examples

      iex> DesktopUI.Graphics.get_window_size(0)
      {:ok, {800, 600}}

  """
  @spec get_window_size(non_neg_integer()) :: {:ok, {pos_integer(), pos_integer()}} | {:error, String.t()}
  def get_window_size(window_id) when is_integer(window_id) do
    nif_get_window_size(window_id)
  end

  @doc """
  Resize a window.

  ## Parameters

  - `window_id` - Window ID returned from `create_window/4`
  - `width` - New width in pixels (positive integer)
  - `height` - New height in pixels (positive integer)

  ## Returns

  - `:ok` - Window resized successfully
  - `{:error, reason}` - Failed to resize window

  ## Examples

      iex> DesktopUI.Graphics.set_window_size(0, 1024, 768)
      :ok

  """
  @spec set_window_size(non_neg_integer(), pos_integer(), pos_integer()) :: :ok | {:error, String.t()}
  def set_window_size(window_id, width, height)
      when is_integer(window_id) and is_integer(width) and is_integer(height) do
    nif_set_window_size(window_id, width, height)
  end

  @doc """
  Set the title of a window.

  ## Parameters

  - `window_id` - Window ID returned from `create_window/4`
  - `title` - New title for the window

  ## Returns

  - `:ok` - Title updated successfully
  - `{:error, reason}` - Failed to update title

  ## Examples

      iex> DesktopUI.Graphics.set_window_title(0, "New Title")
      :ok

  """
  @spec set_window_title(non_neg_integer(), String.t()) :: :ok | {:error, String.t()}
  def set_window_title(window_id, title) when is_integer(window_id) do
    nif_set_window_title(window_id, title)
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

  # ============================================================================
  # Renderer and Drawing API
  # ============================================================================

  @doc """
  Create a new SDL2 renderer for a window.

  A renderer handles drawing operations for a window. Each window can have
  at most one renderer. The renderer is created with hardware acceleration
  and vsync enabled for smooth rendering.

  ## Parameters

  - `window_id` - Window ID returned from `create_window/4`

  ## Returns

  - `{:ok, renderer_id}` - Renderer created successfully
  - `{:error, reason}` - Renderer creation failed

  ## Examples

      iex> DesktopUI.Graphics.sdl_init()
      {:ok, %{}}
      iex> DesktopUI.Graphics.create_window("My Window", 800, 600)
      {:ok, 0}
      iex> DesktopUI.Graphics.create_renderer(0)
      {:ok, 0}

  """
  @spec create_renderer(non_neg_integer()) :: {:ok, non_neg_integer()} | {:error, String.t()}
  def create_renderer(window_id) when is_integer(window_id) do
    nif_create_renderer(window_id)
  end

  @doc """
  Destroy an SDL2 renderer and release its resources.

  ## Parameters

  - `renderer_id` - Renderer ID returned from `create_renderer/1`

  ## Returns

  - `:ok` - Renderer destroyed successfully
  - `{:error, reason}` - Renderer destruction failed

  ## Examples

      iex> DesktopUI.Graphics.destroy_renderer(0)
      :ok

  """
  @spec destroy_renderer(non_neg_integer()) :: :ok | {:error, String.t()}
  def destroy_renderer(renderer_id) when is_integer(renderer_id) do
    nif_destroy_renderer(renderer_id)
  end

  @doc """
  Set the draw color for a renderer.

  This sets the color that will be used for drawing operations like
  `clear_render/1`, `draw_rect/6`, and `fill_rect/6`. Each component
  should be a value between 0 and 255.

  ## Parameters

  - `renderer_id` - Renderer ID returned from `create_renderer/1`
  - `r` - Red component (0-255)
  - `g` - Green component (0-255)
  - `b` - Blue component (0-255)
  - `a` - Alpha component (0-255, 255 = fully opaque)

  ## Returns

  - `:ok` - Draw color set successfully
  - `{:error, reason}` - Operation failed

  ## Examples

      iex> DesktopUI.Graphics.set_render_draw_color(0, 255, 0, 0, 255)
      :ok

  """
  @spec set_render_draw_color(non_neg_integer(), 0..255, 0..255, 0..255, 0..255) ::
          :ok | {:error, String.t()}
  def set_render_draw_color(renderer_id, r, g, b, a)
      when is_integer(renderer_id) and is_integer(r) and is_integer(g) and is_integer(b) and
             is_integer(a) do
    nif_set_render_draw_color(renderer_id, r, g, b, a)
  end

  @doc """
  Clear the renderer target with the current draw color.

  This fills the entire render target with the color set by
  `set_render_draw_color/5`.

  ## Parameters

  - `renderer_id` - Renderer ID returned from `create_renderer/1`

  ## Returns

  - `:ok` - Renderer cleared successfully
  - `{:error, reason}` - Operation failed

  ## Examples

      iex> DesktopUI.Graphics.set_render_draw_color(0, 0, 0, 0, 255)
      :ok
      iex> DesktopUI.Graphics.clear_render(0)
      :ok

  """
  @spec clear_render(non_neg_integer()) :: :ok | {:error, String.t()}
  def clear_render(renderer_id) when is_integer(renderer_id) do
    nif_clear_render(renderer_id)
  end

  @doc """
  Draw an outline rectangle.

  Draws the outline of a rectangle at the specified position with the
  specified color. The color is specified as a tuple `{r, g, b, a}` where
  each component is a value between 0 and 255.

  This function temporarily changes the draw color for this operation only,
  then restores the previous color.

  ## Parameters

  - `renderer_id` - Renderer ID returned from `create_renderer/1`
  - `x` - X position in pixels
  - `y` - Y position in pixels
  - `w` - Width in pixels
  - `h` - Height in pixels
  - `color` - Color tuple `{r, g, b, a}` where each component is 0-255

  ## Returns

  - `:ok` - Rectangle drawn successfully
  - `{:error, reason}` - Operation failed

  ## Examples

      iex> DesktopUI.Graphics.draw_rect(0, 10, 10, 100, 50, {255, 0, 0, 255})
      :ok

  """
  @spec draw_rect(non_neg_integer(), integer(), integer(), integer(), integer(), {0..255, 0..255, 0..255, 0..255}) ::
          :ok | {:error, String.t()}
  def draw_rect(renderer_id, x, y, w, h, color)
      when is_integer(renderer_id) and is_integer(x) and is_integer(y) and is_integer(w) and
             is_integer(h) and is_tuple(color) do
    nif_draw_rect(renderer_id, x, y, w, h, color)
  end

  @doc """
  Draw a filled rectangle.

  Draws a filled rectangle at the specified position with the specified color.
  The color is specified as a tuple `{r, g, b, a}` where each component is a
  value between 0 and 255.

  This function temporarily changes the draw color for this operation only,
  then restores the previous color.

  ## Parameters

  - `renderer_id` - Renderer ID returned from `create_renderer/1`
  - `x` - X position in pixels
  - `y` - Y position in pixels
  - `w` - Width in pixels
  - `h` - Height in pixels
  - `color` - Color tuple `{r, g, b, a}` where each component is 0-255

  ## Returns

  - `:ok` - Rectangle drawn successfully
  - `{:error, reason}` - Operation failed

  ## Examples

      iex> DesktopUI.Graphics.fill_rect(0, 10, 10, 100, 50, {0, 255, 0, 255})
      :ok

  """
  @spec fill_rect(non_neg_integer(), integer(), integer(), integer(), integer(), {0..255, 0..255, 0..255, 0..255}) ::
          :ok | {:error, String.t()}
  def fill_rect(renderer_id, x, y, w, h, color)
      when is_integer(renderer_id) and is_integer(x) and is_integer(y) and is_integer(w) and
             is_integer(h) and is_tuple(color) do
    nif_fill_rect(renderer_id, x, y, w, h, color)
  end

  @doc """
  Present the rendered content to the screen.

  This swaps the buffers to display what has been rendered since the last
  call to `present_render/1`. You must call this function after drawing
  operations to make them visible on screen.

  ## Parameters

  - `renderer_id` - Renderer ID returned from `create_renderer/1`

  ## Returns

  - `:ok` - Content presented successfully
  - `{:error, reason}` - Operation failed

  ## Examples

      iex> DesktopUI.Graphics.present_render(0)
      :ok

  ## Typical Rendering Loop

      # Clear screen with black
      DesktopUI.Graphics.set_render_draw_color(0, 0, 0, 0, 255)
      DesktopUI.Graphics.clear_render(0)

      # Draw a red rectangle
      DesktopUI.Graphics.fill_rect(0, 10, 10, 100, 50, {255, 0, 0, 255})

      # Draw a blue outline rectangle
      DesktopUI.Graphics.draw_rect(0, 20, 20, 80, 30, {0, 0, 255, 255})

      # Present to screen
      DesktopUI.Graphics.present_render(0)

  """
  @spec present_render(non_neg_integer()) :: :ok | {:error, String.t()}
  def present_render(renderer_id) when is_integer(renderer_id) do
    nif_present_render(renderer_id)
  end

  # ============================================================================
  # Event Polling API
  # ============================================================================

  @doc """
  Poll for the next available event without blocking.

  This function checks if there are any pending events in the SDL2 event queue
  and returns the first one if available. If no events are available, it returns
  `:no_event` immediately without blocking.

  ## Returns

  - `event` - An event tuple such as:
    - `{:quit}` - User requested application quit
    - `{:mouse_button_down, button, x, y}` - Mouse button pressed
    - `{:mouse_button_up, button, x, y}` - Mouse button released
    - `{:mouse_motion, x, y, xrel, yrel}` - Mouse moved
    - `{:key_down, keycode, modifiers}` - Key pressed
    - `{:key_up, keycode, modifiers}` - Key released
    - `{:window_event, event_id, data}` - Window state changed
  - `:no_event` - No events available
  - `{:error, reason}` - Failed to poll for events

  ## Event Types

  ### Quit Event
      {:quit}

  ### Mouse Button Events
      {:mouse_button_down, button, x, y}
      {:mouse_button_up, button, x, y}

  Where `button` is one of: `:left`, `:middle`, `:right`, `:x1`, `:x2`

  ### Mouse Motion Event
      {:mouse_motion, x, y, xrel, yrel}

  Where `xrel` and `yrel` are the relative motion since the last event.

  ### Keyboard Events
      {:key_down, keycode, modifiers}
      {:key_up, keycode, modifiers}

  Where `keycode` is one of:
    - Letter keys: `:key_a` through `:key_z`
    - Number keys: `:key_0` through `:key_9`
    - Special keys: `:key_escape`, `:key_return`, `:key_space`, `:key_backspace`,
      `:key_tab`, `:key_home`, `:key_end`, `:key_insert`, `:key_delete`,
      `:key_left`, `:key_right`, `:key_up`, `:key_down`, `:key_pageup`,
      `:key_pagedown`, `:key_f1` through `:key_f12`

  Where `modifiers` is a map:
      %{shift: boolean(), ctrl: boolean(), alt: boolean(), gui: boolean()}

  ### Window Events
      {:window_event, event_id, data1, data2}

  Where `event_id` is one of: `:shown`, `:hidden`, `:exposed`, `:moved`,
  `:resized`, `:size_changed`, `:minimized`, `:maximized`, `:restored`,
  `:enter`, `:leave`, `:focus_gained`, `:focus_lost`, `:close`

  ## Examples

  Poll for events in a loop:

      loop do
        case DesktopUI.Graphics.poll_event() do
          {:quit} ->
            # User wants to quit
            :quit

          {:mouse_button_down, :left, x, y} ->
            # Left mouse button clicked at x, y
            handle_click(x, y)

          {:key_down, :key_escape, _modifiers} ->
            # Escape key pressed
            :quit

          {:key_down, keycode, modifiers} ->
            # Some other key pressed
            handle_key(keycode, modifiers)

          :no_event ->
            # No events, continue loop
            :continue

          {:error, reason} ->
            # Error occurred
            {:error, reason}
        end
      end

  """
  @spec poll_event() ::
          term() | :no_event | {:error, String.t()}
  def poll_event do
    nif_poll_event()
  end

  @doc """
  Wait for an event with a timeout.

  This function blocks until an event is available or the timeout expires.
  This is useful for event loops that want to wait efficiently for user input.

  ## Parameters

  - `timeout` - Timeout in milliseconds (non-negative integer)

  ## Returns

  - `event` - An event tuple (see `poll_event/0` for event types)
  - `:timeout` - No event occurred before timeout
  - `{:error, reason}` - Failed to wait for events

  ## Examples

  Wait up to 1 second for an event:

      case DesktopUI.Graphics.wait_event(1000) do
        {:quit} -> :quit
        {:key_down, keycode, modifiers} -> handle_key(keycode, modifiers)
        :timeout -> IO.puts("No events for 1 second")
        {:error, reason} -> {:error, reason}
      end

  Wait indefinitely (use a very large timeout):

      # Using 10 years as effectively infinite
      DesktopUI.Graphics.wait_event(315_360_000_000)

  """
  @spec wait_event(integer()) ::
          term() | :timeout | {:error, String.t()}
  def wait_event(timeout) when is_integer(timeout) do
    # Treat negative timeouts as 0
    normalized_timeout = if timeout < 0, do: 0, else: timeout
    nif_wait_event(normalized_timeout)
  end

  # ============================================================================
  # Convenience Wrapper API
  # ============================================================================
  #
  # The following functions provide a more ergonomic API for common operations
  # by automatically managing renderers and accepting flexible color formats.
  #
  # ## Color Formats
  #
  # Wrapper functions accept multiple color formats:
  #
  # - **Map:** `%{r: 255, g: 0, b: 0, a: 255}`
  # - **Tuple:** `{255, 0, 0, 255}`
  # - **Named colors:** `:red`, `:blue`, `:green`, `:yellow`, `:cyan`, `:magenta`,
  #   `:black`, `:white`, `:gray`, `:dark_gray`, `:light_gray`, `:transparent`
  # - **Hex string:** `"#FF0000"`, `"#FF0000FF"`, `"#F00"`
  #
  # ## Automatic Renderer Management
  #
  # Wrapper functions that take `window_id` automatically create and cache a
  # renderer for that window on first use. The renderer is automatically
  # destroyed when the window is destroyed.
  #
  # ## Examples
  #
  # Using the wrapper API with named colors:
  #
  #     # Initialize and create a window
  #     DesktopUI.Graphics.init()
  #     {:ok, window_id} = DesktopUI.Graphics.create_window("My App", 800, 600)
  #
  #     # Draw with automatic renderer management and flexible colors
  #     DesktopUI.Graphics.clear_window(window_id, :black)
  #     DesktopUI.Graphics.fill_rect_on_window(window_id, 10, 10, 100, 50, :red)
  #     DesktopUI.Graphics.draw_rect_on_window(window_id, 120, 10, 100, 50, "#00FF00")
  #     DesktopUI.Graphics.present_window(window_id)
  #
  #     # Cleanup (renderer destroyed automatically)
  #     DesktopUI.Graphics.destroy_window(window_id)

  @doc """
  Initialize the SDL2 subsystem (convenience alias for `sdl_init/0`).

  This is a simplified name for `sdl_init/0` that makes initialization
  more discoverable for new users.

  ## Returns

  - `{:ok, %{}}` - SDL2 initialized successfully
  - `{:error, reason}` - Initialization failed

  ## Examples

      DesktopUI.Graphics.init()
      {:ok, %{}}

  """
  @spec init() :: {:ok, map()} | {:error, String.t()}
  def init, do: sdl_init()

  @doc """
  Clear a window to a solid color.

  This is a convenience function that automatically creates a renderer for
  the window if needed, sets the draw color, and clears the window.

  ## Parameters

  - `window_id` - Window ID from `create_window/4`
  - `color` - Color in any supported format (map, tuple, atom, or hex string)

  ## Returns

  - `:ok` - Window cleared successfully
  - `{:error, reason}` - Operation failed

  ## Examples

      DesktopUI.Graphics.clear_window(window_id, :black)
      DesktopUI.Graphics.clear_window(window_id, {255, 0, 0, 255})
      DesktopUI.Graphics.clear_window(window_id, %{r: 0, g: 0, b: 0, a: 255})
      DesktopUI.Graphics.clear_window(window_id, "#000000")

  """
  @spec clear_window(non_neg_integer(), term()) :: :ok | {:error, String.t()}
  def clear_window(window_id, color) do
    with {:ok, renderer_id} <- ensure_renderer(window_id),
         {r, g, b, a} <- DesktopUI.Color.normalize(color),
         :ok <- set_render_draw_color(renderer_id, r, g, b, a),
      do: clear_render(renderer_id)
  end

  @doc """
  Draw an outline rectangle on a window.

  This is a convenience function that automatically creates a renderer for
  the window if needed and draws an outline rectangle.

  ## Parameters

  - `window_id` - Window ID from `create_window/4`
  - `x` - X coordinate of top-left corner
  - `y` - Y coordinate of top-left corner
  - `w` - Width of rectangle
  - `h` - Height of rectangle
  - `color` - Color in any supported format (map, tuple, atom, or hex string)

  ## Returns

  - `:ok` - Rectangle drawn successfully
  - `{:error, reason}` - Operation failed

  ## Examples

      DesktopUI.Graphics.draw_rect_on_window(window_id, 10, 10, 100, 50, :red)
      DesktopUI.Graphics.draw_rect_on_window(window_id, 10, 10, 100, 50, "#FF0000")

  """
  @spec draw_rect_on_window(non_neg_integer(), integer(), integer(), integer(), integer(), term()) ::
          :ok | {:error, String.t()}
  def draw_rect_on_window(window_id, x, y, w, h, color) do
    with {:ok, renderer_id} <- ensure_renderer(window_id),
         {r, g, b, a} <- DesktopUI.Color.normalize(color),
      do: nif_draw_rect(renderer_id, x, y, w, h, {r, g, b, a})
  end

  @doc """
  Draw a filled rectangle on a window.

  This is a convenience function that automatically creates a renderer for
  the window if needed and draws a filled rectangle.

  ## Parameters

  - `window_id` - Window ID from `create_window/4`
  - `x` - X coordinate of top-left corner
  - `y` - Y coordinate of top-left corner
  - `w` - Width of rectangle
  - `h` - Height of rectangle
  - `color` - Color in any supported format (map, tuple, atom, or hex string)

  ## Returns

  - `:ok` - Rectangle drawn successfully
  - `{:error, reason}` - Operation failed

  ## Examples

      DesktopUI.Graphics.fill_rect_on_window(window_id, 10, 10, 100, 50, :blue)
      DesktopUI.Graphics.fill_rect_on_window(window_id, 10, 10, 100, 50, "#0000FF")

  """
  @spec fill_rect_on_window(non_neg_integer(), integer(), integer(), integer(), integer(), term()) ::
          :ok | {:error, String.t()}
  def fill_rect_on_window(window_id, x, y, w, h, color) do
    with {:ok, renderer_id} <- ensure_renderer(window_id),
         {r, g, b, a} <- DesktopUI.Color.normalize(color),
      do: nif_fill_rect(renderer_id, x, y, w, h, {r, g, b, a})
  end

  @doc """
  Present the rendered content to the screen.

  This is a convenience function that automatically creates a renderer for
  the window if needed and presents the rendered content.

  ## Parameters

  - `window_id` - Window ID from `create_window/4`

  ## Returns

  - `:ok` - Content presented successfully
  - `{:error, reason}` - Operation failed

  ## Examples

      DesktopUI.Graphics.present_window(window_id)

  """
  @spec present_window(non_neg_integer()) :: :ok | {:error, String.t()}
  def present_window(window_id) do
    with {:ok, renderer_id} <- ensure_renderer(window_id),
      do: present_render(renderer_id)
  end

  # ============================================================================
  # Helper Functions
  # ============================================================================

  @doc false
  # Ensure a renderer exists for the given window, creating one if needed.
  defp ensure_renderer(window_id) do
    case get_renderer_for_window(window_id) do
      {:ok, renderer_id} ->
        {:ok, renderer_id}

      :error ->
        case create_renderer(window_id) do
          {:ok, renderer_id} ->
            cache_renderer(window_id, renderer_id)
            {:ok, renderer_id}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @doc false
  # Get the cached renderer for a window.
  defp get_renderer_for_window(window_id) do
    case DesktopUI.RendererCache.get_renderer(window_id) do
      {:ok, renderer_id} -> {:ok, renderer_id}
      :error -> :error
    end
  rescue
    # RendererCache not started - this can happen during early initialization
    _ -> :error
  end

  @doc false
  # Cache the renderer association for a window.
  defp cache_renderer(window_id, renderer_id) do
    DesktopUI.RendererCache.put_renderer(window_id, renderer_id)
  end

  @doc false
  # Remove the renderer cache for a window and destroy the renderer.
  defp remove_renderer_cache(window_id) do
    case get_renderer_for_window(window_id) do
      {:ok, renderer_id} ->
        DesktopUI.RendererCache.delete_renderer(window_id)
        destroy_renderer(renderer_id)

      :error ->
        :ok
    end
  end

  # ============================================================================
  # NIF Loading
  # ============================================================================

  @on_load :load_nif

  # Load the NIF library when the module is first loaded
  defp load_nif do
    # Note: RendererCache GenServer handles ETS table creation
    # It is started as part of the application supervision tree

    nif_path = case :code.priv_dir(:desktop_ui) do
      {:error, _} -> "desktop_ui_nif"  # Fallback when app not loaded
      dir -> Path.join(dir, "desktop_ui_nif")
    end

    case load_nif_file(nif_path) do
      :ok ->
        # NIF loaded successfully
        :ok

      {:error, reason} ->
        require Logger
        Logger.warning("""
        Failed to load NIF library: #{inspect(reason)}
        NIF path: #{nif_path}

        The Graphics module will use fallback implementations.
        For full graphics support, please install SDL2:

          Ubuntu/Debian: sudo apt-get install libsdl2-dev
          macOS: brew install sdl2
        """)

        :ok
    end
  end

  defp load_nif_file(nif_path) do
    # :erlang.load_nif automatically adds the platform-specific extension (.so on Linux, .dylib on macOS)
    # So we pass the path without extension and let BEAM handle it
    load_nif_attempt(nif_path)
  end

  defp load_nif_attempt(path) do
    require Logger
    Logger.debug("Attempting to load NIF from: #{inspect(path)}")

    # Load the NIF - the module name in ERL_NIF_INIT (Elixir.DesktopUI.Graphics)
    # must match the module loading it
    case :erlang.load_nif(path, nil) do
      :ok -> :ok
      {:error, {:reload, _}} -> :ok  # Already loaded, that's fine
      {:error, reason} -> {:error, reason}
    end
  end

  # ============================================================================
  # NIF Function Stubs
  # ============================================================================

  # These functions are implemented in the C NIF.
  # If the NIF is not loaded, these stubs will be called instead.
  # These are marked as public with @doc false so sub-modules can call them.

  @doc false
  def nif_init_nif do
    error_not_loaded()
  end

  @doc false
  def nif_get_version do
    "0.3.0-fallback"
  end

  @doc false
  def nif_get_error do
    "NIF not loaded"
  end

  @doc false
  def nif_is_initialized do
    "false"
  end

  # Window management NIF stubs
  @doc false
  def nif_sdl_init do
    error_not_loaded()
  end

  @doc false
  def nif_sdl_quit do
    error_not_loaded()
  end

  @doc false
  def nif_create_window(_title, _width, _height, _flags) do
    error_not_loaded()
  end

  @doc false
  def nif_destroy_window(_window_id) do
    error_not_loaded()
  end

  @doc false
  def nif_get_window_size(_window_id) do
    error_not_loaded()
  end

  @doc false
  def nif_set_window_size(_window_id, _width, _height) do
    error_not_loaded()
  end

  @doc false
  def nif_set_window_title(_window_id, _title) do
    error_not_loaded()
  end

  # Renderer and drawing NIF stubs
  @doc false
  def nif_create_renderer(_window_id) do
    error_not_loaded()
  end

  @doc false
  def nif_destroy_renderer(_renderer_id) do
    error_not_loaded()
  end

  @doc false
  def nif_set_render_draw_color(_renderer_id, _r, _g, _b, _a) do
    error_not_loaded()
  end

  @doc false
  def nif_clear_render(_renderer_id) do
    error_not_loaded()
  end

  @doc false
  def nif_draw_rect(_renderer_id, _x, _y, _w, _h, _color) do
    error_not_loaded()
  end

  @doc false
  def nif_fill_rect(_renderer_id, _x, _y, _w, _h, _color) do
    error_not_loaded()
  end

  @doc false
  def nif_present_render(_renderer_id) do
    error_not_loaded()
  end

  # Event polling NIF stubs
  @doc false
  def nif_poll_event do
    error_not_loaded()
  end

  @doc false
  def nif_wait_event(_timeout) do
    error_not_loaded()
  end

  defp error_not_loaded do
    {:error, "NIF not loaded. Please install SDL2 development libraries."}
  end
end

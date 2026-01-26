defmodule DesktopUI.Renderer do
  @moduledoc """
  Behaviour for DesktopUI renderer implementations.

  This behaviour defines the interface that all renderer modules must implement.
  Renderers are responsible for drawing widget trees to some output (e.g., SDL2 windows).

  ## Required Callbacks

  * `init/1` - Initialize the renderer with a window
  * `render/2` - Render a widget tree
  * `cleanup/1` - Clean up renderer resources

  ## Optional Callbacks

  * `cleanup_window/1` - Clean up window-specific resources (e.g., ETS entries)

  ## Example

      defmodule MyRenderer do
        @behaviour DesktopUI.Renderer

        @impl true
        def init(window_id) do
          # Initialize renderer for the given window
          {:ok, %{window_id: window_id}}
        end

        @impl true
        def render(renderer, widget) do
          # Render the widget tree
          :ok
        end

        @impl true
        def cleanup(renderer) do
          # Clean up renderer resources
          :ok
        end

        @impl true
        def cleanup_window(window_id) do
          # Clean up any window-specific resources (optional)
          :ok
        end
      end
  """

  @doc """
  Initialize the renderer with a window.

  ## Parameters

  - `window_id` - Window identifier

  ## Returns

  - `{:ok, renderer}` - Renderer initialized successfully
  - `{:error, reason}` - Initialization failed
  """
  @callback init(window_id :: non_neg_integer()) :: {:ok, term()} | {:error, String.t()}

  @doc """
  Render a widget tree.

  ## Parameters

  - `renderer` - Renderer state from `init/1`
  - `widget` - Widget tree to render

  ## Returns

  - `:ok` - Rendered successfully
  - `{:error, reason}` - Rendering failed
  """
  @callback render(renderer :: term(), widget :: DesktopUI.Widget.t()) :: :ok | {:error, String.t()}

  @doc """
  Clean up renderer resources.

  ## Parameters

  - `renderer` - Renderer state from `init/1`

  ## Returns

  - `:ok` - Cleanup completed
  """
  @callback cleanup(renderer :: term()) :: :ok

  @doc """
  Clean up window-specific resources.

  This callback is optional and is called when a window is being destroyed.
  It allows the renderer to clean up any window-specific resources such as
  ETS table entries, cached data, etc.

  ## Parameters

  - `window_id` - Window identifier

  ## Returns

  - `:ok` - Cleanup completed

  ## Default Implementation

  By default, this function returns `:ok` and does nothing.
  """
  @callback cleanup_window(window_id :: non_neg_integer()) :: :ok

  @optional_callbacks [cleanup_window: 1]
end

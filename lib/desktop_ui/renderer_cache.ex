defmodule DesktopUI.RendererCache do
  @moduledoc """
  GenServer that owns and manages the renderer cache ETS table.

  This GenServer addresses the hot reload issue where ETS tables created in
  @on_load survive module reloads with stale references. By having a GenServer
  own the ETS table, the table is automatically cleaned up when the GenServer
  terminates (during hot reload).

  ## Architecture

  - The ETS table is created in the GenServer's `init/1` callback
  - The GenServer owns the table, so it's automatically deleted on termination
  - All cache operations go through the GenServer API

  ## Hot Reload Safety

  When code is reloaded:
  1. Old GenServer terminates → ETS table deleted
  2. New GenServer starts → Fresh ETS table created
  3. No stale references remain
  """

  use GenServer
  require Logger

  @table_name :desktop_ui_renderers

  # ============================================================
  # Client API
  # ============================================================

  @doc """
  Start the RendererCache GenServer.
  """
  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @doc """
  Get the cached renderer ID for a window.
  """
  def get_renderer(window_id) do
    GenServer.call(__MODULE__, {:get_renderer, window_id})
  end

  @doc """
  Cache a renderer ID for a window.
  """
  def put_renderer(window_id, renderer_id) do
    GenServer.call(__MODULE__, {:put_renderer, window_id, renderer_id})
  end

  @doc """
  Remove the renderer cache for a window.
  """
  def delete_renderer(window_id) do
    GenServer.call(__MODULE__, {:delete_renderer, window_id})
  end

  @doc """
  Get all cached window-renderer pairs.
  """
  def list_all do
    GenServer.call(__MODULE__, :list_all)
  end

  @doc """
  Clear all renderer caches.
  """
  def clear do
    GenServer.call(__MODULE__, :clear)
  end

  @doc """
  Get the ETS table name (for direct access when needed).
  Note: Prefer using the API functions above for safety.
  """
  def table_name, do: @table_name

  # ============================================================
  # Server Callbacks
  # ============================================================

  @impl true
  def init(_opts) do
    # Create ETS table - this GenServer is the owner
    # Using :set for O(1) lookups and :public to allow direct access
    # when performance is critical
    table = :ets.new(@table_name, [:named_table, :public, :set])

    Logger.debug("RendererCache: Created ETS table #{inspect(@table_name)}")

    {:ok, %{table: table}}
  end

  @impl true
  def handle_call({:get_renderer, window_id}, _from, state) do
    result =
      case :ets.lookup(@table_name, window_id) do
        [{^window_id, renderer_id}] -> {:ok, renderer_id}
        [] -> :error
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:put_renderer, window_id, renderer_id}, _from, state) do
    true = :ets.insert(@table_name, {window_id, renderer_id})
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:delete_renderer, window_id}, _from, state) do
    result = :ets.delete(@table_name, window_id)
    {:reply, result, state}
  end

  @impl true
  def handle_call(:list_all, _from, state) do
    result = :ets.tab2list(@table_name)
    {:reply, result, state}
  end

  @impl true
  def handle_call(:clear, _from, state) do
    true = :ets.delete_all_objects(@table_name)
    {:reply, :ok, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("RendererCache: Received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # ============================================================
  # Termination Callback
  # ============================================================

  @impl true
  def terminate(_reason, _state) do
    # ETS table is automatically deleted when this process terminates
    # because we created it (not another process)
    Logger.debug("RendererCache: Terminating - ETS table will be deleted")
    :ok
  end
end

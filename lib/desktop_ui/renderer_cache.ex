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
  - Table access is `:private` - only the owning GenServer can access it

  ## Access Control

  The ETS table is private to prevent unauthorized access:
  - Only the RendererCache GenServer can read/write the table
  - All access must go through the GenServer API (get_renderer, put_renderer, etc.)
  - This prevents accidental or malicious modification of renderer cache

  ## Hot Reload Safety

  When code is reloaded:
  1. Old GenServer terminates → ETS table deleted
  2. New GenServer starts → Fresh ETS table created
  3. No stale references remain
  """

  use GenServer
  require Logger

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

  # ============================================================
  # Server Callbacks
  # ============================================================

  @impl true
  def init(_opts) do
    # Create ETS table - this GenServer is the owner
    # Using :private for access control - only this process can access the table
    # This prevents unauthorized direct access to the cache
    table = :ets.new(:desktop_ui_renderers, [:private, :set])

    Logger.debug("RendererCache: Created private ETS table")

    {:ok, %{table: table}}
  end

  @impl true
  def handle_call({:get_renderer, window_id}, _from, state) do
    result =
      case :ets.lookup(state.table, window_id) do
        [{^window_id, renderer_id}] -> {:ok, renderer_id}
        [] -> :error
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:put_renderer, window_id, renderer_id}, _from, state) do
    true = :ets.insert(state.table, {window_id, renderer_id})
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:delete_renderer, window_id}, _from, state) do
    result = :ets.delete(state.table, window_id)
    {:reply, result, state}
  end

  @impl true
  def handle_call(:list_all, _from, state) do
    result = :ets.tab2list(state.table)
    {:reply, result, state}
  end

  @impl true
  def handle_call(:clear, _from, state) do
    true = :ets.delete_all_objects(state.table)
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

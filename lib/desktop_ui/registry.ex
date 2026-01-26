defmodule DesktopUI.Registry do
  @moduledoc """
  Process registry for DesktopUI components.

  This registry provides reliable process discovery for DesktopUI components,
  avoiding the race conditions and fragility of using `Supervisor.which_children`.

  Components are registered with unique keys, allowing fast and reliable lookup.
  When a registered process terminates, it is automatically unregistered.

  ## Implementation

  The Registry uses a **per-instance ETS table** to support multiple Runtime
  instances (e.g., in tests). Each Registry process has its own ETS table,
  preventing state pollution between test runs.

  ## Example

      # Register a component (requires registry PID)
      DesktopUI.Registry.register(registry_pid, :root_component, self())

      # Lookup a component (requires registry PID)
      case DesktopUI.Registry.lookup(registry_pid, :root_component) do
        {:ok, pid} -> # Found
        :error -> # Not found
      end

  """

  use GenServer
  require Logger

  @doc """
  Start the registry.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc """
  Register a component with the registry.

  ## Parameters

  - `registry_pid` - PID of the Registry process
  - `key` - Unique identifier for the component (e.g., `:root_component`)
  - `pid` - PID of the component process

  ## Returns

  - `:ok` - Successfully registered
  - `{:error, reason}` - Registration failed

  """
  @spec register(pid(), term(), pid()) :: :ok | {:error, term()}
  def register(registry_pid, key, pid) when is_pid(registry_pid) and is_pid(pid) do
    # Use GenServer.call so the Registry process does the monitoring
    # This ensures DOWN messages go to the Registry, not the caller
    GenServer.call(registry_pid, {:register, key, pid})
  end

  @doc """
  Lookup a component by key.

  ## Parameters

  - `registry_pid` - PID of the Registry process
  - `key` - Unique identifier for the component

  ## Returns

  - `{:ok, pid}` - Component found
  - `:error` - Component not found

  """
  @spec lookup(pid(), term()) :: {:ok, pid()} | :error
  def lookup(registry_pid, key) when is_pid(registry_pid) do
    # Get the ETS table reference and perform lookup
    # Direct ETS read for performance - no GenServer call needed for the read itself
    try do
      table = GenServer.call(registry_pid, {:get_table})

      case :ets.lookup(table, key) do
        [{^key, {pid, _ref}}] -> {:ok, pid}
        [] -> :error
        other -> :error
      end
    catch
      :exit, _ -> :error
    rescue
      ArgumentError -> :error
    end
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Create a protected ETS table owned by this Registry process
    # :protected allows owner and processes with the same "heir" or through the owner
    # We use :protected instead of :private to allow lookups from any process
    # but only the owner can write
    table = :ets.new(:desktop_ui_registry, [:set, :protected])

    {:ok, %{table: table}}
  end

  @impl true
  def handle_call({:register, key, pid}, {from_pid, _ref}, state) do
    # Monitor the process being registered
    ref = Process.monitor(pid)

    # Store both the PID and the monitor reference
    :ets.insert(state.table, {key, {pid, ref}})

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:get_table}, _from, state) do
    # Return the table reference for direct lookups
    {:reply, state.table, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Auto-unregister dead processes
    :ets.match_delete(state.table, {:_, {pid, :_}})
    {:noreply, state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    # Delete the ETS table on termination
    # Since the table is owned by this process, it will be deleted anyway,
    # but we do it explicitly for clarity
    :ets.delete(state.table)
    :ok
  end
end

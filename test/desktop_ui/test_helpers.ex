defmodule DesktopUI.TestHelpers do
  @moduledoc """
  Common test helpers for DesktopUI tests.

  This module provides reusable helper functions for setting up tests,
  managing ETS tables, and waiting for async operations.
  """

  @doc """
  Wait for a condition to be true within a timeout.

  ## Parameters

  - `fun` - Function that returns truthy value when condition is met
  - `max_retries` - Maximum number of retries (default: 10)
  - `retry_delay` - Delay between retries in ms (default: 20)

  ## Returns

  `true` if condition was met, `false` if timeout exceeded

  ## Examples

      TestHelpers.wait_for_condition(fn ->
        Process.whereis(:my_process) != nil
      end)

  """
  @spec wait_for_condition((-> boolean()), pos_integer(), pos_integer()) :: boolean()
  def wait_for_condition(fun, max_retries \\ 10, retry_delay \\ 20) do
    wait_for_condition(fun, max_retries, retry_delay, 0)
  end

  defp wait_for_condition(_fun, max_retries, _retry_delay, attempt) when attempt >= max_retries do
    false
  end

  defp wait_for_condition(fun, max_retries, retry_delay, attempt) do
    if fun.() do
      true
    else
      Process.sleep(retry_delay)
      wait_for_condition(fun, max_retries, retry_delay, attempt + 1)
    end
  end

  @doc """
  Clear all DesktopUI ETS tables for a fresh test state.

  This safely clears tables that may exist, ignoring errors for tables
  that don't exist.

  """
  @spec clear_ets_tables() :: :ok
  def clear_ets_tables do
    # Clear the RenderingCoordinator's ETS tables
    tables = [
      :desktop_ui_rendering_coordinator_components,
      :desktop_ui_rendering_coordinator_metrics,
      :desktop_ui_rendering_coordinator_layouts
    ]

    Enum.each(tables, fn table_name ->
      try do
        :ets.delete_all_objects(table_name)
      rescue
        _ -> :ok
      end
    end)

    :ok
  end

  @doc """
  Stop the signal bus if it's running.

  This is useful for test cleanup when the signal bus might not have
  been properly stopped by a previous test.

  """
  @spec stop_signal_bus_if_running(atom()) :: :ok
  def stop_signal_bus_if_running(bus_name \\ :desktop_ui) do
    case Process.whereis(bus_name) do
      nil ->
        :ok

      pid when is_pid(pid) ->
        try do
          GenServer.stop(pid, :normal, 1000)
        catch
          _, _ -> Process.exit(pid, :kill)
        end

        wait_for_process_unregistered(bus_name, 100)
    end
  end

  # Wait for a process name to be unregistered
  defp wait_for_process_unregistered(name, timeout) do
    wait_for_condition(fn -> Process.whereis(name) == nil end, div(timeout, 10), 10)
  end

  @doc """
  Start the Jido.Signal.Bus if it's not already running.

  ## Parameters

  - `name` - The name to register the bus under (default: :desktop_ui)

  ## Returns

  `{:ok, pid}` if the bus was started, `:already_exists` if it was already running

  """
  @spec ensure_signal_bus_started(atom()) :: {:ok, pid()} | :already_exists
  def ensure_signal_bus_started(name \\ :desktop_ui) do
    case Process.whereis(name) do
      nil ->
        # Also ensure the Jido.Signal.Registry is running
        case Process.whereis(Jido.Signal.Registry) do
          nil ->
            {:ok, _} = Registry.start_link(keys: :unique, name: Jido.Signal.Registry)

          _ ->
            :ok
        end

        {:ok, _pid} = Jido.Signal.Bus.start_link(name: name)

      _pid ->
        :already_exists
    end
  end
end

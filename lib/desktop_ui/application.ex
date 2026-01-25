defmodule DesktopUI.Application do
  @moduledoc """
  Application module for DesktopUI.

  This module handles the application lifecycle, including startup and
  shutdown procedures. It sets up the necessary supervision tree and
  ensures proper cleanup on application termination.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Add child processes here as needed
    ]

    opts = [strategy: :one_for_one, name: DesktopUI.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def stop(_state) do
    # Cleanup renderer cache ETS table on application shutdown
    cleanup_renderer_cache()
    :ok
  end

  defp cleanup_renderer_cache do
    try do
      # Delete the ETS table if it exists
      :ets.delete(:desktop_ui_renderers)
      :ok
    rescue
      ArgumentError -> :ok  # Table doesn't exist
    end
  end
end

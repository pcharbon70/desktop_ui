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
      # RendererCache GenServer owns the renderer cache ETS table
      # This ensures proper cleanup on hot reload and application shutdown
      {DesktopUI.RendererCache, []}
    ]

    opts = [strategy: :one_for_one, name: DesktopUI.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def stop(_state) do
    # Cleanup is handled automatically by the RendererCache GenServer
    # When it terminates, the ETS table is automatically deleted
    :ok
  end
end

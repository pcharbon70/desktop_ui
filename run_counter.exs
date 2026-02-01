#!/usr/bin/env elixir

# DesktopUI Counter Demo Runner
#
# This script starts the DesktopUI Counter demonstration application.
# It initializes the runtime with the Counter component as the root UI.
#
# Usage:
#   mix run run_counter.exs
#
# Or with IEx for interactive debugging:
#   iex -S mix run run_counter.exs

# Start the DesktopUI Runtime with the Counter component
case DesktopUI.Runtime.start_link(
  root_component: DesktopUI.Examples.Counter,
  renderer: DesktopUI.Renderer.SDL2,
  window_title: "DesktopUI Counter Demo",
  window_width: 400,
  window_height: 500
) do
  {:ok, _runtime} ->
    IO.puts("""
    DesktopUI Counter Demo started!
    ================================

    A window should appear with:
    - Title: "DesktopUI Counter Demo"
    - Counter display starting at 0
    - Buttons: -, +, Reset, Quit

    Press Ctrl+C to stop the application.
    """)

  {:error, reason} ->
    IO.puts(:stderr, "Failed to start DesktopUI Runtime: #{inspect(reason)}")
    System.at_exit(fn _ -> exit(1) end)
end

# Keep the application running
Process.sleep(:infinity)

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

# Add SDL2 to PATH for Windows
# SDL2.dll is bundled in priv/sdl2/ for development
case :os.type() do
  {:win32, _} ->
    # Add priv/sdl2 to PATH so SDL2.dll can be found
    sdl2_path = Path.join([:code.priv_dir(:desktop_ui), "sdl2"])
    if File.exists?(sdl2_path) do
      current_path = System.get_env("PATH", "")
      System.put_env("PATH", "#{sdl2_path};#{current_path}")
    end

  _ ->
    # Unix: SDL2 is expected to be in standard system paths
    :ok
end

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

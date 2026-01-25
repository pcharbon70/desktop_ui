defmodule DesktopUI.Integration.TestHelper do
  @moduledoc """
  Helper module for integration tests.
  Provides cross-test utilities that can be used at compile time.
  """

  alias DesktopUI.Graphics

  @doc """
  Check if SDL2 is available for testing.
  This function can be called at compile time to set module attributes.
  """
  def sdl2_available? do
    case Graphics.sdl_init() do
      :ok ->
        Graphics.sdl_quit()
        true

      {:error, _reason} ->
        false
    end
  rescue
    _ -> false
  end
end

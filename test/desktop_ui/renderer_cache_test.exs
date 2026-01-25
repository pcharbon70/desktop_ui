defmodule DesktopUI.RendererCacheTest do
  use ExUnit.Case
  alias DesktopUI.RendererCache

  doctest RendererCache

  describe "RendererCache GenServer" do
    setup do
      # Ensure RendererCache is running
      case Process.whereis(RendererCache) do
        nil ->
          {:ok, _pid} = RendererCache.start_link()

        pid ->
          {:ok, pid}
      end

      :ok
    end

    test "get_renderer returns :error for non-existent window" do
      assert :error = RendererCache.get_renderer(999)
    end

    test "put_renderer and get_renderer" do
      window_id = 1
      renderer_id = 100

      assert :ok = RendererCache.put_renderer(window_id, renderer_id)
      assert {:ok, ^renderer_id} = RendererCache.get_renderer(window_id)
    end

    test "put_renderer overwrites existing renderer" do
      window_id = 2
      renderer_id_1 = 200
      renderer_id_2 = 201

      assert :ok = RendererCache.put_renderer(window_id, renderer_id_1)
      assert {:ok, ^renderer_id_1} = RendererCache.get_renderer(window_id)

      assert :ok = RendererCache.put_renderer(window_id, renderer_id_2)
      assert {:ok, ^renderer_id_2} = RendererCache.get_renderer(window_id)
    end

    test "delete_renderer removes cached entry" do
      window_id = 3
      renderer_id = 300

      assert :ok = RendererCache.put_renderer(window_id, renderer_id)
      assert {:ok, ^renderer_id} = RendererCache.get_renderer(window_id)

      assert true = RendererCache.delete_renderer(window_id)
      assert :error = RendererCache.get_renderer(window_id)
    end

    test "delete_renderer handles non-existent entry" do
      # :ets.delete returns true if the table exists, false only if table doesn't exist
      # Since we're not testing table existence here, just verify it doesn't crash
      assert true = RendererCache.delete_renderer(999)
      assert :error = RendererCache.get_renderer(999)
    end

    test "list_all returns all cached renderers" do
      RendererCache.clear()

      RendererCache.put_renderer(1, 100)
      RendererCache.put_renderer(2, 200)
      RendererCache.put_renderer(3, 300)

      result = RendererCache.list_all()
      assert length(result) == 3
      assert {1, 100} in result
      assert {2, 200} in result
      assert {3, 300} in result
    end

    test "clear removes all entries" do
      RendererCache.put_renderer(1, 100)
      RendererCache.put_renderer(2, 200)

      assert length(RendererCache.list_all()) == 2

      assert :ok = RendererCache.clear()
      assert [] == RendererCache.list_all()
    end

    test "table_name returns the ETS table name" do
      assert RendererCache.table_name() == :desktop_ui_renderers
    end

    test "concurrent access is safe" do
      # Spawn multiple processes that access the cache concurrently
      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            RendererCache.put_renderer(i, i * 100)
            Process.sleep(1)
            RendererCache.get_renderer(i)
          end)
        end

      results = Task.await_many(tasks, 5000)
      assert length(results) == 10

      # All operations should have succeeded
      Enum.each(results, fn
        {:ok, _renderer_id} -> :ok
        _ -> flunk("Expected all operations to succeed")
      end)
    end
  end
end

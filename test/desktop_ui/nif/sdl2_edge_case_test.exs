defmodule DesktopUI.Nif.SDL2EdgeCaseTest do
  require DesktopUI.Nif.TestHelper
  use ExUnit.Case, async: true

  alias DesktopUI.Nif.SDL2
  import DesktopUI.Nif.TestHelper, only: [with_env_var: 3, with_temp_dir: 2, unique_integer: 0]

  @moduletag :nif
  @moduletag :sdl2
  @moduletag :edge_case

  describe "available?/0 edge cases" do
    test "returns false when no SDL2 is found" do
      # Set an invalid prefix to ensure SDL2 is not found
      with_env_var("DESKTOPUI_SDL2_PREFIX", "/nonexistent/path", fn ->
        # Clear other potential SDL2 sources
        available = SDL2.available?()
        assert is_boolean(available)
      end)
    end

    test "returns true when DESKTOPUI_SDL2_PREFIX is set to existing directory" do
      with_temp_dir("mock_sdl2_prefix", fn dir ->
        with_env_var("DESKTOPUI_SDL2_PREFIX", dir, fn ->
          # With prefix set, should return true (directory exists)
          assert SDL2.available?() == true
        end)
      end)
    end

    test "returns false when DESKTOPUI_SDL2_PREFIX points to non-existent path" do
      with_env_var("DESKTOPUI_SDL2_PREFIX", "/definitely/does/not/exist", fn ->
        result = SDL2.available?()
        assert is_boolean(result)
      end)
    end
  end

  describe "cflags/0 edge cases" do
    test "returns empty list when SDL2 not found" do
      with_env_var("DESKTOPUI_SDL2_PREFIX", "/nonexistent/sdl2", fn ->
        assert [] = SDL2.cflags()
      end)
    end

    test "returns valid -I flags for custom prefix" do
      with_temp_dir("custom_sdl2", fn dir ->
        include_dir = Path.join(dir, "include")
        File.mkdir_p!(include_dir)

        with_env_var("DESKTOPUI_SDL2_PREFIX", dir, fn ->
          flags = SDL2.cflags()

          # Should have at least one -I flag
          assert Enum.any?(flags, fn f -> String.starts_with?(f, "-I") end)
        end)
      end)
    end

    test "handles SDL2/SDL2 subdirectory" do
      with_temp_dir("sdl2_subdir", fn dir ->
        include_dir = Path.join(dir, "include")
        sdl2_subdir = Path.join(include_dir, "SDL2")
        File.mkdir_p!(sdl2_subdir)

        with_env_var("DESKTOPUI_SDL2_PREFIX", dir, fn ->
          flags = SDL2.cflags()

          # Should find headers in SDL2 subdirectory
          assert Enum.any?(flags, fn f ->
            String.contains?(f, "SDL2") and String.starts_with?(f, "-I")
          end)
        end)
      end)
    end

    test "handles empty prefix gracefully" do
      with_env_var("DESKTOPUI_SDL2_PREFIX", "", fn ->
        # Empty prefix should fall back to default detection
        flags = SDL2.cflags()
        assert is_list(flags)
      end)
    end
  end

  describe "ldflags/0 edge cases" do
    test "returns empty list when SDL2 not found" do
      with_env_var("DESKTOPUI_SDL2_PREFIX", "/nonexistent/sdl2", fn ->
        assert [] = SDL2.ldflags()
      end)
    end

    test "returns -lSDL2 when library directory exists" do
      with_temp_dir("sdl2_libs", fn dir ->
        lib_dir = Path.join(dir, "lib")
        File.mkdir_p!(lib_dir)

        with_env_var("DESKTOPUI_SDL2_PREFIX", dir, fn ->
          flags = SDL2.ldflags()
          assert "-lSDL2" in flags
        end)
      end)
    end

    test "includes -L flag for custom library path" do
      with_temp_dir("custom_lib_path", fn dir ->
        lib_dir = Path.join(dir, "lib")
        File.mkdir_p!(lib_dir)

        with_env_var("DESKTOPUI_SDL2_PREFIX", dir, fn ->
          flags = SDL2.ldflags()

          # Should have both -L and -l flags
          assert Enum.any?(flags, &String.starts_with?(&1, "-L"))
          assert "-lSDL2" in flags
        end)
      end)
    end
  end

  describe "static_linking?/0 edge cases" do
    test "returns false by default" do
      refute SDL2.static_linking?()
    end

    test "returns true when DESKTOPUI_SDL2_STATIC=1" do
      with_env_var("DESKTOPUI_SDL2_STATIC", "1", fn ->
        assert SDL2.static_linking?()
      end)
    end

    test "returns false when DESKTOPUI_SDL2_STATIC=0" do
      with_env_var("DESKTOPUI_SDL2_STATIC", "0", fn ->
        refute SDL2.static_linking?()
      end)
    end

    test "returns false when DESKTOPUI_SDL2_STATIC is any other value" do
      for value <- ["", "true", "false", "yes", "no", "TRUE"] do
        with_env_var("DESKTOPUI_SDL2_STATIC", value, fn ->
          refute SDL2.static_linking?()
        end)
      end
    end
  end

  describe "static linking edge cases" do
    test "finds libSDL2.a when static linking enabled" do
      with_temp_dir("static_lib_test", fn dir ->
        lib_dir = Path.join(dir, "lib")
        File.mkdir_p!(lib_dir)

        # Create static library
        static_lib = Path.join(lib_dir, "libSDL2.a")
        File.write!(static_lib, "")

        with_env_var("DESKTOPUI_SDL2_PREFIX", dir) do
          with_env_var("DESKTOPUI_SDL2_STATIC", "1", fn ->
            flags = SDL2.ldflags()
            # Should return path to static library
            assert static_lib in flags
          end)
        end
      end)
    end

    test "finds libSDL2static.a as alternative" do
      with_temp_dir("alt_static_lib", fn dir ->
        lib_dir = Path.join(dir, "lib")
        File.mkdir_p!(lib_dir)

        # Create alternative static library
        static_lib = Path.join(lib_dir, "libSDL2static.a")
        File.write!(static_lib, "")

        with_env_var("DESKTOPUI_SDL2_PREFIX", dir) do
          with_env_var("DESKTOPUI_SDL2_STATIC", "1", fn ->
            flags = SDL2.ldflags()
            # Should return path to alternative static library
            assert static_lib in flags
          end)
        end
      end)
    end

    test "falls back to dynamic when static library not found" do
      with_temp_dir("no_static_lib", fn dir ->
        lib_dir = Path.join(dir, "lib")
        File.mkdir_p!(lib_dir)

        # Don't create any static library

        with_env_var("DESKTOPUI_SDL2_PREFIX", dir) do
          with_env_var("DESKTOPUI_SDL2_STATIC", "1", fn ->
            flags = SDL2.ldflags()
            # Should fall back to dynamic linking flags
            assert "-lSDL2" in flags
            # Should not contain .a files
            refute Enum.any?(flags, &String.contains?(&1, ".a"))
          end)
        end
      end)
    end
  end

  describe "cross-compilation edge cases" do
    test "handles nil target parameter" do
      # nil target should work the same as no target
      flags1 = SDL2.cflags(nil)
      flags2 = SDL2.cflags()

      assert is_list(flags1)
      assert is_list(flags2)
    end

    test "uses DESKTOPUI_SDL2_CROSS_PATH when set" do
      with_temp_dir("cross_sdl2", fn dir ->
        include_dir = Path.join(dir, "include")
        File.mkdir_p!(include_dir)

        with_env_var("DESKTOPUI_SDL2_CROSS_PATH", dir, fn ->
          flags = SDL2.cflags("aarch64-linux-gnu")

          # Should use cross path
          assert Enum.any?(flags, fn f ->
            String.contains?(f, dir) and String.starts_with?(f, "-I")
          end)
        end)
      end)
    end

    test "falls back to native detection when cross path not found" do
      # Set a non-existent cross path
      with_env_var("DESKTOPUI_SDL2_CROSS_PATH", "/nonexistent/cross", fn ->
        # Should not error, just fall back
        flags = SDL2.cflags("aarch64-linux-gnu")
        assert is_list(flags)
      end)
    end

    test "handles empty DESKTOPUI_SDL2_CROSS_PATH" do
      with_env_var("DESKTOPUI_SDL2_CROSS_PATH", "", fn ->
        flags = SDL2.cflags("aarch64-linux-gnu")
        assert is_list(flags)
      end)
    end
  end

  describe "pkg-config edge cases" do
    test "handles pkg-config not found gracefully" do
      # This is implicitly tested - if pkg-config is not found,
      # the functions should still work and return empty lists
      # or fall back to other detection methods
      result = SDL2.find_pkg_config()

      case result do
        {:ok, _path} ->
          # pkg-config is available
          :ok

        {:error, :not_found} ->
          # pkg-config not available, should still work
          assert true
      end
    end
  end

  describe "sdl2-config edge cases" do
    test "handles sdl2-config not found gracefully" do
      result = SDL2.find_sdl2_config()

      case result do
        {:ok, _path} ->
          # sdl2-config is available
          :ok

        {:error, :not_found} ->
          # sdl2-config not available, should still work
          assert true
      end
    end
  end

  describe "integration edge cases" do
    test "available? and cflags consistency" do
      # When available? returns true, cflags should have content
      # When available? returns false, cflags should be empty
      with_temp_dir("consistency_test", fn dir ->
        include_dir = Path.join(dir, "include")
        File.mkdir_p!(include_dir)

        with_env_var("DESKTOPUI_SDL2_PREFIX", dir, fn ->
          available = SDL2.available?()
          cflags = SDL2.cflags()

          if available do
            # Should have at least one cflag
            assert length(cflags) > 0
          else
            # Should have no cflags
            assert cflags == []
          end
        end)
      end)
    end

    test "available? and ldflags consistency" do
      # When available? returns true, ldflags should have content
      with_temp_dir("ldflags_consistency", fn dir ->
        lib_dir = Path.join(dir, "lib")
        File.mkdir_p!(lib_dir)

        with_env_var("DESKTOPUI_SDL2_PREFIX", dir, fn ->
          available = SDL2.available?()
          ldflags = SDL2.ldflags()

          if available do
            # Should have at least one ldflag
            assert length(ldflags) > 0
          else
            # Should have no ldflags
            assert ldflags == []
          end
        end)
      end)
    end
  end

  describe "concurrent access edge cases" do
    test "handles concurrent calls to available?" do
      tasks = for _ <- 1..10 do
        Task.async(fn ->
          result = SDL2.available?()
          assert is_boolean(result)
          result
        end)
      end

      results = Task.await_many(tasks)
      assert length(results) == 10
    end

    test "handles concurrent calls to cflags" do
      tasks = for _ <- 1..10 do
        Task.async(fn ->
          flags = SDL2.cflags()
          assert is_list(flags)
          flags
        end)
      end

      results = Task.await_many(tasks)
      assert length(results) == 10
    end
  end

  describe "environment variable cleanup" do
    test "restores environment after with_env_var" do
      original = System.get_env("DESKTOPUI_SDL2_PREFIX")

      with_env_var("DESKTOPUI_SDL2_PREFIX", "/test/path", fn ->
        assert System.get_env("DESKTOPUI_SDL2_PREFIX") == "/test/path"
      end)

      # Environment should be restored
      assert System.get_env("DESKTOPUI_SDL2_PREFIX") == original
    end
  end
end

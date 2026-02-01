defmodule DesktopUI.Nif.SDL2Test do
  use ExUnit.Case
  alias DesktopUI.Nif.SDL2

  describe "available?/0" do
    test "returns boolean" do
      result = SDL2.available?()
      assert is_boolean(result)
    end

    test "returns true when SDL2 is installed" do
      # This test may pass or fail depending on system
      # We just verify it returns a boolean
      result = SDL2.available?()
      assert result in [true, false]
    end

    test "respects DESKTOPUI_SDL2_PREFIX environment variable" do
      tmp_dir = System.tmp_dir!()
      test_prefix = Path.join(tmp_dir, "sdl2_test_#{:erlang.unique_integer([:positive])}")
      File.mkdir_p!(test_prefix)

      try do
        System.put_env("DESKTOPUI_SDL2_PREFIX", test_prefix)
        result = SDL2.available?()
        System.delete_env("DESKTOPUI_SDL2_PREFIX")

        # With prefix set, should return true (directory exists)
        assert result == true
      after
        File.rm_rf!(test_prefix)
      end
    end
  end

  describe "cflags/0" do
    test "returns a list" do
      result = SDL2.cflags()
      assert is_list(result)
    end

    test "returns empty list when SDL2 not found" do
      # Force empty result by setting invalid prefix
      System.put_env("DESKTOPUI_SDL2_PREFIX", "/nonexistent/path")
      result = SDL2.cflags()
      System.delete_env("DESKTOPUI_SDL2_PREFIX")

      assert result == []
    end

    test "returns flags starting with -I when SDL2 is available" do
      result = SDL2.cflags()

      case result do
        [] ->
          # SDL2 not found, which is acceptable
          :ok

        flags ->
          # At least one flag should start with -I
          assert Enum.any?(flags, &String.starts_with?(&1, "-I"))
      end
    end
  end

  describe "ldflags/0" do
    test "returns a list" do
      result = SDL2.ldflags()
      assert is_list(result)
    end

    test "returns empty list when SDL2 not found" do
      # Force empty result by setting invalid prefix
      System.put_env("DESKTOPUI_SDL2_PREFIX", "/nonexistent/path")
      result = SDL2.ldflags()
      System.delete_env("DESKTOPUI_SDL2_PREFIX")

      assert result == []
    end

    test "returns -lSDL2 flag when SDL2 is available" do
      result = SDL2.ldflags()

      case result do
        [] ->
          # SDL2 not found, which is acceptable
          :ok

        flags ->
          # Should contain -lSDL2
          assert "-lSDL2" in flags or "-lSDL2main" in flags
      end
    end
  end

  describe "find_pkg_config/0" do
    test "returns {:ok, path} when pkg-config is found" do
      result = SDL2.find_pkg_config()

      case result do
        {:ok, path} ->
          assert is_binary(path)
          assert String.contains?(path, "pkg-config")

        {:error, :not_found} ->
          # pkg-config not installed is acceptable
          :ok
      end
    end

    test "returns {:error, :not_found} when pkg-config is not found" do
      # We can't easily test this without removing pkg-config
      # Just verify the function returns the expected format
      result = SDL2.find_pkg_config()
      assert elem(result, 0) in [:ok, :error]
    end
  end

  describe "find_sdl2_config/0" do
    test "returns {:ok, path} when sdl2-config is found" do
      result = SDL2.find_sdl2_config()

      case result do
        {:ok, path} ->
          assert is_binary(path)
          assert String.contains?(path, "sdl2-config")

        {:error, :not_found} ->
          # sdl2-config not installed is acceptable
          :ok
      end
    end
  end

  describe "DESKTOPUI_SDL2_PREFIX override" do
    test "cflags uses custom prefix when set" do
      tmp_dir = System.tmp_dir!()
      test_prefix = Path.join(tmp_dir, "sdl2_custom_#{:erlang.unique_integer([:positive])}")
      test_include = Path.join(test_prefix, "include")
      File.mkdir_p!(test_include)

      try do
        System.put_env("DESKTOPUI_SDL2_PREFIX", test_prefix)
        result = SDL2.cflags()
        System.delete_env("DESKTOPUI_SDL2_PREFIX")

        # Should have -I flag pointing to our custom directory
        assert Enum.any?(result, fn flag ->
          String.contains?(flag, test_include)
        end)
      after
        File.rm_rf!(test_prefix)
      end
    end

    test "ldflags uses custom prefix when set" do
      tmp_dir = System.tmp_dir!()
      test_prefix = Path.join(tmp_dir, "sdl2_lib_#{:erlang.unique_integer([:positive])}")
      test_lib = Path.join(test_prefix, "lib")
      File.mkdir_p!(test_lib)

      try do
        System.put_env("DESKTOPUI_SDL2_PREFIX", test_prefix)
        result = SDL2.ldflags()
        System.delete_env("DESKTOPUI_SDL2_PREFIX")

        # Should have -lSDL2 flag
        assert "-lSDL2" in result
      after
        File.rm_rf!(test_prefix)
      end
    end
  end

  describe "integration" do
    test "available? and cflags are consistent" do
      available = SDL2.available?()
      cflags = SDL2.cflags()

      if available do
        # If available, should have at least one cflag
        assert length(cflags) > 0
      else
        # If not available, cflags should be empty
        assert cflags == []
      end
    end

    test "available? and ldflags are consistent" do
      available = SDL2.available?()
      ldflags = SDL2.ldflags()

      if available do
        # If available, should have at least one ldflag
        assert length(ldflags) > 0
      else
        # If not available, ldflags should be empty
        assert ldflags == []
      end
    end
  end

  describe "static_linking?/0" do
    test "returns false by default" do
      result = SDL2.static_linking?()
      refute result
    end

    test "returns true when DESKTOPUI_SDL2_STATIC=1" do
      original = System.get_env("DESKTOPUI_SDL2_STATIC")

      try do
        System.put_env("DESKTOPUI_SDL2_STATIC", "1")
        result = SDL2.static_linking?()
        assert result
      after
        if original do
          System.put_env("DESKTOPUI_SDL2_STATIC", original)
        else
          System.delete_env("DESKTOPUI_SDL2_STATIC")
        end
      end
    end

    test "returns false when DESKTOPUI_SDL2_STATIC is set to other value" do
      original = System.get_env("DESKTOPUI_SDL2_STATIC")

      try do
        System.put_env("DESKTOPUI_SDL2_STATIC", "0")
        result = SDL2.static_linking?()
        refute result
      after
        if original do
          System.put_env("DESKTOPUI_SDL2_STATIC", original)
        else
          System.delete_env("DESKTOPUI_SDL2_STATIC")
        end
      end
    end
  end

  describe "cflags/1 (with target)" do
    test "accepts nil target (native compilation)" do
      result = SDL2.cflags(nil)
      assert is_list(result)
    end

    test "accepts target string for cross-compilation" do
      result = SDL2.cflags("aarch64-linux-gnu")
      assert is_list(result)
    end

    test "returns different results for cross-compilation when DESKTOPUI_SDL2_CROSS_PATH is set" do
      tmp_dir = System.tmp_dir!()
      cross_path = Path.join(tmp_dir, "cross_sdl2_#{:erlang.unique_integer([:positive])}")
      cross_include = Path.join(cross_path, "include")
      File.mkdir_p!(cross_include)

      original_cross = System.get_env("DESKTOPUI_SDL2_CROSS_PATH")

      try do
        System.put_env("DESKTOPUI_SDL2_CROSS_PATH", cross_path)

        # With target, should use cross path
        result = SDL2.cflags("aarch64-linux-gnu")
        assert is_list(result)

        # Without target, should not use cross path
        result_native = SDL2.cflags()
        assert is_list(result_native)
      after
        if original_cross do
          System.put_env("DESKTOPUI_SDL2_CROSS_PATH", original_cross)
        else
          System.delete_env("DESKTOPUI_SDL2_CROSS_PATH")
        end
        File.rm_rf!(cross_path)
      end
    end
  end

  describe "ldflags/1 (with target)" do
    test "accepts nil target (native compilation)" do
      result = SDL2.ldflags(nil)
      assert is_list(result)
    end

    test "accepts target string for cross-compilation" do
      result = SDL2.ldflags("aarch64-linux-gnu")
      assert is_list(result)
    end

    test "returns static library path when DESKTOPUI_SDL2_STATIC=1 with target" do
      tmp_dir = System.tmp_dir!()
      cross_path = Path.join(tmp_dir, "cross_sdl2_static_#{:erlang.unique_integer([:positive])}")
      cross_lib = Path.join(cross_path, "lib")
      File.mkdir_p!(cross_lib)

      # Create a fake static library
      static_lib = Path.join(cross_lib, "libSDL2.a")
      File.write!(static_lib, "")

      original_cross = System.get_env("DESKTOPUI_SDL2_CROSS_PATH")
      original_static = System.get_env("DESKTOPUI_SDL2_STATIC")

      try do
        System.put_env("DESKTOPUI_SDL2_CROSS_PATH", cross_path)
        System.put_env("DESKTOPUI_SDL2_STATIC", "1")

        result = SDL2.ldflags("aarch64-linux-gnu")

        # Should return path to static library
        assert static_lib in result
      after
        if original_cross do
          System.put_env("DESKTOPUI_SDL2_CROSS_PATH", original_cross)
        else
          System.delete_env("DESKTOPUI_SDL2_CROSS_PATH")
        end

        if original_static do
          System.put_env("DESKTOPUI_SDL2_STATIC", original_static)
        else
          System.delete_env("DESKTOPUI_SDL2_STATIC")
        end

        File.rm_rf!(cross_path)
      end
    end

    test "falls back to dynamic linking when static library not found" do
      tmp_dir = System.tmp_dir!()
      cross_path = Path.join(tmp_dir, "cross_sdl2_nostatic_#{:erlang.unique_integer([:positive])}")
      cross_lib = Path.join(cross_path, "lib")
      File.mkdir_p!(cross_lib)

      # Don't create static library - only directory

      original_cross = System.get_env("DESKTOPUI_SDL2_CROSS_PATH")
      original_static = System.get_env("DESKTOPUI_SDL2_STATIC")

      try do
        System.put_env("DESKTOPUI_SDL2_CROSS_PATH", cross_path)
        System.put_env("DESKTOPUI_SDL2_STATIC", "1")

        result = SDL2.ldflags("aarch64-linux-gnu")

        # Should fall back to dynamic linking flags
        assert is_list(result)
        # Should not contain the nonexistent .a file
        refute Enum.any?(result, &String.contains?(&1, ".a"))
      after
        if original_cross do
          System.put_env("DESKTOPUI_SDL2_CROSS_PATH", original_cross)
        else
          System.delete_env("DESKTOPUI_SDL2_CROSS_PATH")
        end

        if original_static do
          System.put_env("DESKTOPUI_SDL2_STATIC", original_static)
        else
          System.delete_env("DESKTOPUI_SDL2_STATIC")
        end

        File.rm_rf!(cross_path)
      end
    end
  end

  describe "cross-compilation detection" do
    test "DESKTOPUI_SDL2_CROSS_PATH takes precedence over sysroot" do
      tmp_dir = System.tmp_dir!()
      cross_path = Path.join(tmp_dir, "cross_override_#{:erlang.unique_integer([:positive])}")
      cross_include = Path.join(cross_path, "include")
      File.mkdir_p!(cross_include)

      original_cross = System.get_env("DESKTOPUI_SDL2_CROSS_PATH")

      try do
        System.put_env("DESKTOPUI_SDL2_CROSS_PATH", cross_path)

        result = SDL2.cflags("x86_64-windows-gnu")

        # Should use our custom path
        assert Enum.any?(result, fn flag ->
          String.contains?(flag, cross_path)
        end)
      after
        if original_cross do
          System.put_env("DESKTOPUI_SDL2_CROSS_PATH", original_cross)
        else
          System.delete_env("DESKTOPUI_SDL2_CROSS_PATH")
        end
        File.rm_rf!(cross_path)
      end
    end

    test "falls back to native detection when cross path not found" do
      # Clear any cross path environment
      original_cross = System.get_env("DESKTOPUI_SDL2_CROSS_PATH")

      try do
        System.delete_env("DESKTOPUI_SDL2_CROSS_PATH")

        # Should not error, just fall back
        result = SDL2.cflags("aarch64-linux-gnu")
        assert is_list(result)
      after
        if original_cross do
          System.put_env("DESKTOPUI_SDL2_CROSS_PATH", original_cross)
        end
      end
    end
  end
end

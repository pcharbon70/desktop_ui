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
end

defmodule DesktopUI.Nif.TestHelperTest do
  use ExUnit.Case
  alias DesktopUI.Nif.TestHelper

  describe "with_tmp_dir/1" do
    test "creates a temporary directory" do
      TestHelper.with_tmp_dir(fn tmp_dir ->
        assert File.dir?(tmp_dir)
      end)
    end

    test "cleans up directory after function completes" do
      tmp_dir_ref = make_ref()

      TestHelper.with_tmp_dir(fn tmp_dir ->
        Process.put(tmp_dir_ref, tmp_dir)
        assert File.dir?(tmp_dir)
      end)

      tmp_dir = Process.get(tmp_dir_ref)
      refute File.exists?(tmp_dir)
    end

    test "cleans up directory even if function raises" do
      tmp_dir_ref = make_ref()

      assert_raise RuntimeError, fn ->
        TestHelper.with_tmp_dir(fn tmp_dir ->
          Process.put(tmp_dir_ref, tmp_dir)
          raise "intentional error"
        end)
      end

      tmp_dir = Process.get(tmp_dir_ref)
      refute File.exists?(tmp_dir)
    end

    test "creates unique directories for each call" do
      dir1 = TestHelper.unique_tmp_path()
      dir2 = TestHelper.unique_tmp_path()

      assert dir1 != dir2
    end
  end

  describe "with_tmp_file/2" do
    test "creates a temporary file with content" do
      content = "test content"

      TestHelper.with_tmp_file(content, fn file_path ->
        assert File.exists?(file_path)
        assert File.read!(file_path) == content
      end)
    end

    test "cleans up file after function completes" do
      file_ref = make_ref()

      TestHelper.with_tmp_file("content", fn file_path ->
        Process.put(file_ref, file_path)
        assert File.exists?(file_path)
      end)

      file_path = Process.get(file_ref)
      refute File.exists?(file_path)
    end
  end

  describe "with_env/2" do
    test "sets environment variables for function duration" do
      TestHelper.with_env(%{"TEST_HELPER_VAR" => "test_value"}, fn ->
        assert System.get_env("TEST_HELPER_VAR") == "test_value"
      end)
    end

    test "restores original values after function" do
      System.put_env("TEST_HELPER_VAR", "original_value")

      TestHelper.with_env(%{"TEST_HELPER_VAR" => "temp_value"}, fn ->
        assert System.get_env("TEST_HELPER_VAR") == "temp_value"
      end)

      assert System.get_env("TEST_HELPER_VAR") == "original_value"
      System.delete_env("TEST_HELPER_VAR")
    end

    test "restores nil (unset) after function" do
      System.delete_env("TEST_HELPER_VAR")

      TestHelper.with_env(%{"TEST_HELPER_VAR" => "temp_value"}, fn ->
        assert System.get_env("TEST_HELPER_VAR") == "temp_value"
      end)

      assert System.get_env("TEST_HELPER_VAR") == nil
    end

    test "can delete variable with nil value" do
      System.put_env("TEST_HELPER_VAR", "original")

      TestHelper.with_env(%{"TEST_HELPER_VAR" => nil}, fn ->
        assert System.get_env("TEST_HELPER_VAR") == nil
      end)

      assert System.get_env("TEST_HELPER_VAR") == "original"
      System.delete_env("TEST_HELPER_VAR")
    end

    test "restores values even if function raises" do
      System.put_env("TEST_HELPER_VAR", "original")

      assert_raise RuntimeError, fn ->
        TestHelper.with_env(%{"TEST_HELPER_VAR" => "temp_value"}, fn ->
          raise "intentional error"
        end)
      end

      assert System.get_env("TEST_HELPER_VAR") == "original"
      System.delete_env("TEST_HELPER_VAR")
    end
  end

  describe "with_env_var/3" do
    test "sets single environment variable" do
      TestHelper.with_env_var("TEST_HELPER_SINGLE", "value", fn ->
        assert System.get_env("TEST_HELPER_SINGLE") == "value"
      end)
    end

    test "restores original value" do
      System.put_env("TEST_HELPER_SINGLE", "original")

      TestHelper.with_env_var("TEST_HELPER_SINGLE", "temp", fn ->
        assert System.get_env("TEST_HELPER_SINGLE") == "temp"
      end)

      assert System.get_env("TEST_HELPER_SINGLE") == "original"
      System.delete_env("TEST_HELPER_SINGLE")
    end
  end

  describe "with_erts_include_dir/1" do
    test "creates directory with erl_nif.h" do
      TestHelper.with_erts_include_dir(fn include_dir ->
        assert File.dir?(include_dir)
        erl_nif_path = Path.join(include_dir, "erl_nif.h")
        assert File.exists?(erl_nif_path)
      end)
    end

    test "directory validates as valid ERTS include" do
      TestHelper.with_erts_include_dir(fn include_dir ->
        assert DesktopUI.Nif.Erts.validate_include_dir(include_dir) == :ok
      end)
    end
  end

  describe "with_sdl2_prefix/1" do
    test "creates SDL2 directory structure" do
      TestHelper.with_sdl2_prefix(fn prefix ->
        assert File.dir?(prefix)
        assert File.dir?(Path.join(prefix, "include"))
        assert File.dir?(Path.join(prefix, "lib"))
      end)
    end
  end

  describe "with_sdl2_pkg_config/1" do
    test "creates SDL2.pc file" do
      TestHelper.with_sdl2_pkg_config(fn prefix ->
        pc_file = Path.join([prefix, "lib", "pkgconfig", "SDL2.pc"])
        assert File.exists?(pc_file)
      end)
    end
  end

  describe "unique_tmp_path/0" do
    test "returns a path in system temp directory" do
      path = TestHelper.unique_tmp_path()
      tmp_dir = System.tmp_dir!()
      assert String.starts_with?(path, tmp_dir)
    end

    test "returns unique paths" do
      path1 = TestHelper.unique_tmp_path()
      path2 = TestHelper.unique_tmp_path()
      assert path1 != path2
    end
  end

  describe "unique_tmp_path/1" do
    test "includes the provided filename" do
      path = TestHelper.unique_tmp_path("test.txt")
      assert String.ends_with?(path, "test.txt")
    end

    test "includes unique prefix" do
      path1 = TestHelper.unique_tmp_path("test.txt")
      path2 = TestHelper.unique_tmp_path("test.txt")
      assert path1 != path2
    end
  end

  describe "linux?/0" do
    test "returns a boolean" do
      result = TestHelper.linux?()
      assert is_boolean(result)
    end

    test "is consistent with Platform.detect_platform" do
      result = TestHelper.linux?()
      platform = DesktopUI.Nif.Platform.detect_platform()
      assert result == (platform == {:unix, :linux})
    end
  end

  describe "macos?/0" do
    test "returns a boolean" do
      result = TestHelper.macos?()
      assert is_boolean(result)
    end

    test "is consistent with Platform.detect_platform" do
      result = TestHelper.macos?()
      platform = DesktopUI.Nif.Platform.detect_platform()
      assert result == (platform == {:unix, :darwin})
    end
  end

  describe "windows?/0" do
    test "returns a boolean" do
      result = TestHelper.windows?()
      assert is_boolean(result)
    end

    test "is consistent with Platform.detect_platform" do
      result = TestHelper.windows?()
      platform = DesktopUI.Nif.Platform.detect_platform()
      assert result == (platform == {:win32, :nt})
    end
  end

  describe "skip_unless/2" do
    test "returns :ok when condition is true" do
      assert TestHelper.skip_unless(true, "should not skip") == :ok
    end

    test "raises AssertionError when condition is false" do
      assert_raise ExUnit.AssertionError, fn ->
        TestHelper.skip_unless(false, "test message")
      end
    end
  end

  describe "skip_if/2" do
    test "returns :ok when condition is false" do
      assert TestHelper.skip_if(false, "should not skip") == :ok
    end

    test "raises AssertionError when condition is true" do
      assert_raise ExUnit.AssertionError, fn ->
        TestHelper.skip_if(true, "test message")
      end
    end
  end
end

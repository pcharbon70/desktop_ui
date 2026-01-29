defmodule DesktopUI.Nif.TestHelper do
  @moduledoc """
  Test helpers for DesktopUI NIF testing.

  This module provides utilities for common test patterns used across
  the NIF-related test suites, including:

  - Temporary file and directory management
  - Environment variable mocking
  - Test setup/teardown helpers
  - Platform-specific test utilities

  ## Examples

      # Using with_tmp_dir for automatic cleanup
      DesktopUI.Nif.TestHelper.with_tmp_dir(fn tmp_dir ->
        File.write!(Path.join(tmp_dir, "test.txt"), "content")
        # Test code here
      end)

      # Using with_env for environment variable testing
      DesktopUI.Nif.TestHelper.with_env(%{"TEST_VAR" => "value"}, fn ->
        # Test code with environment variable set
      end)

  """

  @doc """
  Executes a function with a temporary directory that is automatically cleaned up.

  The temporary directory is created before the function is called and
  removed after the function returns, regardless of whether it succeeds or fails.

  ## Examples

      TestHelper.with_tmp_dir(fn tmp_dir ->
        File.write!(Path.join(tmp_dir, "file.txt"), "content")
        assert File.exists?(Path.join(tmp_dir, "file.txt"))
      end)
      # Directory is automatically removed

  """
  @spec with_tmp_dir((Path.t() -> result)) :: result when result: var
  def with_tmp_dir(fun) when is_function(fun, 1) do
    tmp_dir = unique_tmp_path()
    File.mkdir_p!(tmp_dir)

    try do
      fun.(tmp_dir)
    after
      File.rm_rf!(tmp_dir)
    end
  end

  @doc """
  Executes a function with a temporary file that is automatically cleaned up.

  Creates a file with the given content, passes the path to the function,
  and removes the file afterward.

  ## Examples

      TestHelper.with_tmp_file("test content", fn file_path ->
        content = File.read!(file_path)
        assert content == "test content"
      end)
      # File is automatically removed

  """
  @spec with_tmp_file(String.t(), (Path.t() -> result)) :: result when result: var
  def with_tmp_file(content, fun) when is_binary(content) and is_function(fun, 1) do
    tmp_file = unique_tmp_path()

    try do
      File.write!(tmp_file, content)
      fun.(tmp_file)
    after
      File.rm!(tmp_file)
    end
  end

  @doc """
  Executes a function with environment variables set.

  Sets the given environment variables before calling the function and
  restores the original values afterward.

  ## Examples

      TestHelper.with_env(%{"TEST_VAR" => "value"}, fn ->
        assert System.get_env("TEST_VAR") == "value"
      end)
      # Environment variable is restored to original value

  """
  @spec with_env(%{String.t() => String.t() | nil}, (() -> result)) :: result when result: var
  def with_env(env_vars, fun) when is_map(env_vars) and is_function(fun, 0) do
    # Save original values
    originals =
      Enum.map(env_vars, fn {key, _val} ->
        {key, System.get_env(key)}
      end)

    # Set new values
    Enum.each(env_vars, fn {key, val} ->
      if val == nil do
        System.delete_env(key)
      else
        System.put_env(key, val)
      end
    end)

    try do
      fun.()
    after
      # Restore original values
      Enum.each(originals, fn {key, val} ->
        if val == nil do
          System.delete_env(key)
        else
          System.put_env(key, val)
        end
      end)
    end
  end

  @doc """
  Executes a function with a single environment variable set.

  Convenience wrapper for `with_env/2` when setting only one variable.

  ## Examples

      TestHelper.with_env_var("TEST_VAR", "value", fn ->
        assert System.get_env("TEST_VAR") == "value"
      end)

  """
  @spec with_env_var(String.t(), String.t() | nil, (() -> result)) :: result when result: var
  def with_env_var(key, value, fun) when is_binary(key) and is_function(fun, 0) do
    with_env(%{key => value}, fun)
  end

  @doc """
  Creates a temporary ERTS include directory structure for testing.

  Creates a directory with a dummy `erl_nif.h` file to simulate
  a valid ERTS include directory.

  ## Examples

      TestHelper.with_erts_include_dir(fn include_dir ->
        assert File.exists?(Path.join(include_dir, "erl_nif.h"))
        assert DesktopUI.Nif.Erts.validate_include_dir(include_dir) == :ok
      end)

  """
  @spec with_erts_include_dir((Path.t() -> result)) :: result when result: var
  def with_erts_include_dir(fun) when is_function(fun, 1) do
    with_tmp_dir(fn tmp_dir ->
      erl_nif_path = Path.join(tmp_dir, "erl_nif.h")
      File.write!(erl_nif_path, "// Dummy erl_nif.h for testing")
      fun.(tmp_dir)
    end)
  end

  @doc """
  Creates a temporary SDL2 directory structure for testing.

  Creates the standard SDL2 directory layout with include and lib subdirectories.

  ## Examples

      TestHelper.with_sdl2_prefix(fn prefix ->
        include_dir = Path.join(prefix, "include")
        lib_dir = Path.join(prefix, "lib")
        assert File.dir?(include_dir)
        assert File.dir?(lib_dir)
      end)

  """
  @spec with_sdl2_prefix((Path.t() -> result)) :: result when result: var
  def with_sdl2_prefix(fun) when is_function(fun, 1) do
    with_tmp_dir fn tmp_dir ->
      include_dir = Path.join(tmp_dir, "include")
      lib_dir = Path.join(tmp_dir, "lib")

      File.mkdir_p!(include_dir)
      File.mkdir_p!(lib_dir)

      fun.(tmp_dir)
    end
  end

  @doc """
  Creates a temporary SDL2 prefix with SDL2.pc file for testing.

  Simulates a pkg-config SDL2 installation.

  ## Examples

      TestHelper.with_sdl2_pkg_config(fn prefix ->
        pc_file = Path.join([prefix, "lib", "pkgconfig", "SDL2.pc"])
        assert File.exists?(pc_file)
      end)

  """
  @spec with_sdl2_pkg_config((Path.t() -> result)) :: result when result: var
  def with_sdl2_pkg_config(fun) when is_function(fun, 1) do
    with_sdl2_prefix fn prefix ->
      pc_dir = Path.join([prefix, "lib", "pkgconfig"])
      File.mkdir_p!(pc_dir)

      pc_file = Path.join(pc_dir, "SDL2.pc")
      File.write!(pc_file, ~s(prefix=#{prefix}))

      fun.(prefix)
    end
  end

  @doc """
  Generates a unique temporary path for testing.

  Uses `System.tmp_dir!/0` combined with a unique integer to create
  a path that won't conflict with other tests.

  ## Examples

      path1 = TestHelper.unique_tmp_path()
      path2 = TestHelper.unique_tmp_path()
      assert path1 != path2

  """
  @spec unique_tmp_path() :: Path.t()
  def unique_tmp_path do
    unique_name = "desktop_ui_test_#{:erlang.unique_integer([:positive, :monotonic])}"
    Path.join([System.tmp_dir!(), unique_name])
  end

  @doc """
  Generates a unique temporary path with a specific filename.

  ## Examples

      path = TestHelper.unique_tmp_path("test_file.txt")
      # Returns something like: /tmp/desktop_ui_test_123/test_file.txt

  """
  @spec unique_tmp_path(String.t()) :: Path.t()
  def unique_tmp_path(filename) when is_binary(filename) do
    Path.join([unique_tmp_path(), filename])
  end

  @doc """
  Returns true if running on Linux.

  ## Examples

      if TestHelper.linux?() do
        # Linux-specific test
      end

  """
  @spec linux?() :: boolean()
  def linux? do
    DesktopUI.Nif.Platform.detect_platform() == {:unix, :linux}
  end

  @doc """
  Returns true if running on macOS.

  ## Examples

      if TestHelper.macos?() do
        # macOS-specific test
      end

  """
  @spec macos?() :: boolean()
  def macos? do
    DesktopUI.Nif.Platform.detect_platform() == {:unix, :darwin}
  end

  @doc """
  Returns true if running on Windows.

  ## Examples

      if TestHelper.windows?() do
        # Windows-specific test
      end

  """
  @spec windows?() :: boolean()
  def windows? do
    DesktopUI.Nif.Platform.detect_platform() == {:win32, :nt}
  end

  @doc """
  Skips the current test with a message if the condition is true.

  Useful for platform-specific tests.

  ## Examples

      test "Linux-specific feature", do
        TestHelper.skip_unless(TestHelper.linux?(), "Linux only")
        # Test code here
      end

  """
  @spec skip_unless(boolean(), String.t()) :: :ok | no_return()
  def skip_unless(true, _message), do: :ok
  def skip_unless(false, message), do: raise(ExUnit.AssertionError, message: message)

  @doc """
  Skips the current test with a message if the condition is false.

  Useful for platform-specific tests.

  ## Examples

      test "skip on Windows", do
        TestHelper.skip_if(TestHelper.windows?(), "Not supported on Windows")
        # Test code here
      end

  """
  @spec skip_if(boolean(), String.t()) :: :ok | no_return()
  def skip_if(false, _message), do: :ok
  def skip_if(true, message), do: raise(ExUnit.AssertionError, message: message)
end

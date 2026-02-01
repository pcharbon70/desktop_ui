defmodule DesktopUI.Nif.TestHelper do
  @moduledoc """
  Test helpers for NIF-related modules.

  This module provides utility functions for testing NIF compilation,
  platform detection, and SDL2 integration.

  ## Examples

      # Temporarily set an environment variable
      TestHelper.with_env_var("MY_VAR", "value", fn ->
        assert System.get_env("MY_VAR") == "value"
      end)

      # Create a temporary directory
      TestHelper.with_temp_dir("test_prefix", fn dir ->
        assert File.dir?(dir)
      end)

  """

  @doc """
  Executes a function with a temporary environment variable set.

  The environment variable is restored to its original value (or deleted)
  after the function completes, even if an error is raised.

  ## Parameters

  - `key` - Environment variable name
  - `value` - Value to set (can be empty string or nil to delete)
  - `fun` - Function to execute with the env var set

  ## Examples

      TestHelper.with_env_var("DESKTOPUI_TARGET", "x86_64-linux-gnu", fn ->
        assert DesktopUI.Nif.Platform.target_triple() == "x86_64-linux-gnu"
      end)

  """
  @spec with_env_var(String.t(), String.t() | nil, (-> any())) :: any()
  def with_env_var(key, value, fun) when is_function(fun, 0) do
    original = System.get_env(key)

    try do
      if value == nil do
        System.delete_env(key)
      else
        System.put_env(key, value)
      end

      fun.()
    after
      if original do
        System.put_env(key, original)
      else
        System.delete_env(key)
      end
    end
  end

  @doc """
  Creates a temporary directory and passes it to the given function.

  The directory and all its contents are deleted after the function completes,
  even if an error is raised.

  ## Parameters

  - `prefix` - Prefix for the temporary directory name
  - `fun` - Function that receives the directory path as argument

  ## Examples

      TestHelper.with_temp_dir("sdl2_test", fn dir ->
        include_dir = Path.join(dir, "include")
        File.mkdir_p!(include_dir)
        # ... use the directory
      end)

  """
  @spec with_temp_dir(String.t(), (-> Path.t())) :: any()
  def with_temp_dir(prefix, fun) when is_function(fun, 1) do
    tmp_dir = Path.join([System.tmp_dir!(), "#{prefix}_#{unique_integer()}"])
    File.mkdir_p!(tmp_dir)

    try do
      fun.(tmp_dir)
    after
      File.rm_rf!(tmp_dir)
    end
  end

  @doc """
  Creates a temporary file with the given content.

  The file is automatically cleaned up after the function completes.

  ## Parameters

  - `content` - Content to write to the file
  - `fun` - Function that receives the file path as argument
  - `extension` - Optional file extension (default: ".tmp")

  ## Examples

      TestHelper.with_temp_file("test content", fn path ->
        assert File.read!(path) == "test content"
      end)

  """
  @spec with_temp_file(String.t(), (-> Path.t()), String.t()) :: any()
  def with_temp_file(content, fun, extension \\ ".tmp") when is_function(fun, 1) do
    with_temp_dir("temp_file", fn dir ->
      path = Path.join(dir, "file_#{unique_integer()}#{extension}")
      File.write!(path, content)

      try do
        fun.(path)
      after
        File.rm!(path)
      end
    end)
  end

  @doc """
  Creates a mock SDL2 directory structure with headers.

  This creates a temporary directory with SDL2 header files for testing
  SDL2 detection without requiring actual SDL2 installation.

  ## Parameters

  - `fun` - Function that receives the prefix path as argument

  ## Examples

      TestHelper.with_mock_sdl2(fn prefix ->
        assert File.dir?(Path.join(prefix, "include"))
      end)

  """
  @spec with_mock_sdl2((-> Path.t())) :: any()
  def with_mock_sdl2(fun) when is_function(fun, 1) do
    with_temp_dir("mock_sdl2", fn prefix ->
      include_dir = Path.join(prefix, "include")
      sdl2_subdir = Path.join(include_dir, "SDL2")
      lib_dir = Path.join(prefix, "lib")

      File.mkdir_p!(sdl2_subdir)
      File.mkdir_p!(lib_dir)

      # Create mock SDL2 header
      File.write!(Path.join(sdl2_subdir, "SDL.h"), mock_sdl_header())
      File.write!(Path.join(include_dir, "SDL.h"), mock_sdl_header())

      # Create mock library file
      File.write!(Path.join(lib_dir, "libSDL2.a"), "")

      fun.(prefix)
    end)
  end

  @doc """
  Creates a mock ERTS directory structure with headers.

  This creates a temporary directory with ERTS header files for testing
  ERTS detection without requiring actual Erlang installation.

  ## Parameters

  - `fun` - Function that receives the include directory path as argument

  ## Examples

      TestHelper.with_mock_erts(fn include_dir ->
        assert File.dir?(include_dir)
        assert File.exists?(Path.join(include_dir, "erl_nif.h"))
      end)

  """
  @spec with_mock_erts((-> Path.t())) :: any()
  def with_mock_erts(fun) when is_function(fun, 1) do
    with_temp_dir("mock_erts", fn tmp_dir ->
      erts_dir = Path.join(tmp_dir, "erts-14.0.0")
      include_dir = Path.join(erts_dir, "include")
      File.mkdir_p!(include_dir)

      # Create mock erl_nif.h
      File.write!(Path.join(include_dir, "erl_nif.h"), mock_erl_nif_header())

      fun.(include_dir)
    end)
  end

  @doc """
  Returns a unique positive integer for test isolation.

  ## Examples

      iex> TestHelper.unique_integer() > 0
      true

  """
  @spec unique_integer() :: pos_integer()
  def unique_integer do
    :erlang.unique_integer([:positive, :monotonic])
  end

  @doc """
  Skips a test if Zig is not installed.

  ## Examples

      describe "zig-specific tests" do
        setup do
          TestHelper.skip_if_zig_not_installed()
          :ok
        end

        test "requires Zig" do
          # ... test that needs Zig
        end
      end

  """
  @spec skip_if_zig_not_installed() :: :ok | {:skip, term()}
  def skip_if_zig_not_installed do
    if DesktopUI.Nif.Zig.installed?() do
      :ok
    else
      {:skip, "Zig is not installed"}
    end
  end

  @doc """
  Skips a test if SDL2 is not installed.

  ## Examples

      describe "SDL2-specific tests" do
        setup do
          TestHelper.skip_if_sdl2_not_available()
          :ok
        end

        test "requires SDL2" do
          # ... test that needs SDL2
        end
      end

  """
  @spec skip_if_sdl2_not_available() :: :ok | {:skip, term()}
  def skip_if_sdl2_not_available do
    if DesktopUI.Nif.SDL2.available?() do
      :ok
    else
      {:skip, "SDL2 is not available"}
    end
  end

  # Private Functions

  defp mock_sdl_header do
    """
    /* Mock SDL2 header for testing */
    #ifndef SDL_H
    #define SDL_H

    typedef struct SDL_Window SDL_Window;
    typedef struct SDL_Renderer SDL_Renderer;

    #endif
    """
  end

  defp mock_erl_nif_header do
    """
    /* Mock erl_nif.h for testing */
    #ifndef ERL_NIF_H
    #define ERL_NIF_H

    typedef struct _ErlNifEnv ErlNifEnv;
    typedef struct _ErlNifFunc ErlNifFunc;
    typedef struct _ErlNifEntry ErlNifEntry;

    #endif
    """
  end
end

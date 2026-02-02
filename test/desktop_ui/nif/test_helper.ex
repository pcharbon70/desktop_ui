defmodule DesktopUI.Nif.TestHelper do
  @moduledoc """
  Helper functions for NIF-related tests.
  """

  @doc """
  Execute a function with a temporary directory.

  The directory is created before the function is called and cleaned up after.
  """
  def with_temp_dir(prefix, fun) do
    dir = Path.join([System.tmp_dir!(), "#{prefix}_#{System.unique_integer()}"])
    File.mkdir_p!(dir)

    try do
      fun.(dir)
    after
      File.rm_rf(dir)
    end
  end

  @doc """
  Execute a function with a temporary file.
  """
  def with_temp_file(content, fun) do
    path = Path.join([System.tmp_dir!(), "temp_#{System.unique_integer()}"])
    File.write!(path, content)

    try do
      fun.(path)
    after
      File.rm(path)
    end
  end

  @doc """
  Execute a function with an environment variable set.

  The environment variable is restored to its original value after the function.
  """
  def with_env_var(key, value, fun) do
    original = System.get_env(key)

    System.put_env(key, value)

    try do
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
  Generate a unique integer for test isolation.
  """
  def unique_integer, do: System.unique_integer([:positive, :monotonic])

  @doc """
  Execute a function with a mocked ERTS include directory.
  """
  def with_mock_erts(fun) do
    with_temp_dir("mock_erts", fn dir ->
      # Create a fake erl_nif.h file
      erts_dir = Path.join(dir, "erts-14.2.1")
      include_dir = Path.join(erts_dir, "include")
      File.mkdir_p!(include_dir)

      erl_nif_path = Path.join(include_dir, "erl_nif.h")
      File.write!(erl_nif_path, """
      // Mock erl_nif.h for testing
      #ifndef ERL_NIF_H
      #define ERL_NIF_H
      typedef struct {
          int dummy;
      } ErlNifEnv;
      #endif
      """)

      # Set ROOTDIR to point to our mock ERTS installation
      original_root = System.get_env("ROOTDIR")
      System.put_env("ROOTDIR", erts_dir)

      try do
        fun.(include_dir)
      after
        if original_root do
          System.put_env("ROOTDIR", original_root)
        else
          System.delete_env("ROOTDIR")
        end
      end
    end)
  end
end

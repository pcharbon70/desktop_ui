defmodule DesktopUI.Nif.ErtsTest do
  use ExUnit.Case
  alias DesktopUI.Nif.Erts

  describe "root_dir/0" do
    test "returns {:ok, path} tuple" do
      result = Erts.root_dir()
      assert {:ok, path} = result
      assert is_binary(path)
    end

    test "returns a path that exists" do
      {:ok, path} = Erts.root_dir()
      assert File.exists?(path)
    end

    test "returns a directory path" do
      {:ok, path} = Erts.root_dir()
      assert File.dir?(path)
    end
  end

  describe "version/0" do
    test "returns {:ok, version} tuple" do
      result = Erts.version()
      assert {:ok, version} = result
      assert is_binary(version)
    end

    test "returns a version string" do
      {:ok, version} = Erts.version()
      assert String.length(version) > 0
    end
  end

  describe "include_dir/0" do
    test "returns {:ok, path} tuple on standard installation" do
      result = Erts.include_dir()

      # Either success or not_found depending on installation
      case result do
        {:ok, path} ->
          assert is_binary(path)
          assert String.contains?(path, "erts")

        {:error, :not_found} ->
          # Non-standard installation is acceptable
          :ok

        {:error, _} ->
          flunk("Unexpected error: #{inspect(result)}")
      end
    end

    test "returns path ending with /include" do
      case Erts.include_dir() do
        {:ok, path} ->
          assert String.ends_with?(path, "/include")

        {:error, _} ->
          # Skip on non-standard installations
          :ok
      end
    end

    test "respects DESKTOPUI_ERTS_INCLUDE environment variable" do
      # Create a temporary directory for testing
      tmp_dir = System.tmp_dir!()
      test_include = Path.join(tmp_dir, "ertestest-include")
      File.mkdir_p!(test_include)

      # Create erl_nif.h to make it valid
      File.write!(Path.join(test_include, "erl_nif.h"), "// dummy")

      try do
        System.put_env("DESKTOPUI_ERTS_INCLUDE", test_include)
        result = Erts.include_dir()
        System.delete_env("DESKTOPUI_ERTS_INCLUDE")

        assert {:ok, ^test_include} = result
      after
        File.rm_rf!(test_include)
      end
    end

    test "validates override path" do
      System.put_env("DESKTOPUI_ERTS_INCLUDE", "/nonexistent/path")
      result = Erts.include_dir()
      System.delete_env("DESKTOPUI_ERTS_INCLUDE")

      assert {:error, :not_found} = result
    end
  end

  describe "validate_include_dir/1" do
    test "returns :ok for valid ERTS include directory" do
      # Find actual ERTS include directory
      case Erts.include_dir() do
        {:ok, actual_path} ->
          assert Erts.validate_include_dir(actual_path) == :ok

        {:error, _} ->
          # Skip if we can't find the real directory
          :ok
      end
    end

    test "returns {:error, :not_found} for non-existent path" do
      result = Erts.validate_include_dir("/this/path/does/not/exist")
      assert {:error, :not_found} = result
    end

    test "returns {:error, :invalid_path} for file instead of directory" do
      # Create a temporary file
      tmp_file = Path.join(System.tmp_dir!(), "test_file_#{:erlang.unique_integer([:positive])}")
      File.write!(tmp_file, "test")

      result = Erts.validate_include_dir(tmp_file)

      File.rm!(tmp_file)

      assert {:error, :invalid_path} = result
    end

    test "returns {:error, :invalid_path} for directory without erl_nif.h" do
      # Create a temporary directory without erl_nif.h
      tmp_dir = Path.join(System.tmp_dir!(), "test_dir_#{:erlang.unique_integer([:positive])}")
      File.mkdir!(tmp_dir)

      result = Erts.validate_include_dir(tmp_dir)

      File.rm_rf!(tmp_dir)

      assert {:error, :invalid_path} = result
    end

    test "returns :ok for directory with erl_nif.h" do
      # Create a temporary directory with erl_nif.h
      tmp_dir = Path.join(System.tmp_dir!(), "test_dir_#{:erlang.unique_integer([:positive])}")
      File.mkdir!(tmp_dir)
      File.write!(Path.join(tmp_dir, "erl_nif.h"), "// dummy")

      result = Erts.validate_include_dir(tmp_dir)

      File.rm_rf!(tmp_dir)

      assert :ok == result
    end
  end

  describe "integration" do
    test "root_dir and include_dir are consistent" do
      case {Erts.root_dir(), Erts.include_dir()} do
        {{:ok, root}, {:ok, include}} ->
          # Include directory should be under root directory
          assert String.starts_with?(include, root)

        _ ->
          # Skip on non-standard installations
          :ok
      end
    end

    test "include_dir contains erl_nif.h when found" do
      case Erts.include_dir() do
        {:ok, path} ->
          erl_nif_path = Path.join(path, "erl_nif.h")
          assert File.exists?(erl_nif_path)

        {:error, _} ->
          # Skip on non-standard installations
          :ok
      end
    end
  end
end

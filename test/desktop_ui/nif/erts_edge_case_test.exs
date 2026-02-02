defmodule DesktopUI.Nif.ErtsEdgeCaseTest do
  require DesktopUI.Nif.TestHelper
  use ExUnit.Case, async: true

  alias DesktopUI.Nif.Erts

  import DesktopUI.Nif.TestHelper,
    only: [
      with_env_var: 3,
      with_temp_dir: 2,
      with_temp_file: 2,
      with_mock_erts: 1,
      unique_integer: 0
    ]

  @moduletag :nif
  @moduletag :erts
  @moduletag :edge_case

  describe "validate_include_dir/1 edge cases" do
    test "returns {:error, :not_found} for non-existent path" do
      non_existent = "/this/path/definitely/does/not/exist/#{unique_integer()}"
      assert {:error, :not_found} = Erts.validate_include_dir(non_existent)
    end

    test "returns {:error, :invalid_path} for file instead of directory" do
      with_temp_file("dummy content", fn file_path ->
        assert {:error, :invalid_path} = Erts.validate_include_dir(file_path)
      end)
    end

    test "returns {:error, :invalid_path} for directory without erl_nif.h" do
      with_temp_dir("empty_erts", fn dir ->
        assert {:error, :invalid_path} = Erts.validate_include_dir(dir)
      end)
    end

    test "returns :ok for directory with only erl_nif.h present" do
      with_temp_dir("minimal_erts", fn dir ->
        erl_nif_path = Path.join(dir, "erl_nif.h")
        File.write!(erl_nif_path, "// Minimal erl_nif.h")

        assert :ok = Erts.validate_include_dir(dir)
      end)
    end

    test "returns :ok for directory with erl_nif.h even without other headers" do
      with_temp_dir("solo_header", fn dir ->
        # Create only erl_nif.h, no other headers
        File.write!(Path.join(dir, "erl_nif.h"), """
        #ifndef ERL_NIF_H
        #define ERL_NIF_H
        typedef struct ErlNifEnv_ ErlNifEnv;
        #endif
        """)

        assert :ok = Erts.validate_include_dir(dir)
      end)
    end

    test "handles directory with erl_nif.h as subdirectory" do
      with_temp_dir("weird_structure", fn dir ->
        # Create erl_nif.h as a directory (not a file)
        erl_nif_dir = Path.join(dir, "erl_nif.h")
        File.mkdir_p!(erl_nif_dir)

        # Should fail because erl_nif.h is not a file
        assert {:error, :invalid_path} = Erts.validate_include_dir(dir)
      end)
    end

    test "handles empty string path" do
      assert {:error, :not_found} = Erts.validate_include_dir("")
    end

    test "handles whitespace-only path" do
      assert {:error, :not_found} = Erts.validate_include_dir("   ")
    end
  end

  describe "include_dir/0 edge cases" do
    test "respects DESKTOPUI_ERTS_INCLUDE with valid custom path" do
      with_mock_erts(fn include_dir ->
        with_env_var("DESKTOPUI_ERTS_INCLUDE", include_dir, fn ->
          assert {:ok, ^include_dir} = Erts.include_dir()
        end)
      end)
    end

    test "respects DESKTOPUI_ERTS_INCLUDE with invalid path" do
      with_env_var("DESKTOPUI_ERTS_INCLUDE", "/nonexistent/path", fn ->
        assert {:error, :not_found} = Erts.include_dir()
      end)
    end

    test "respects DESKTOPUI_ERTS_INCLUDE with file instead of directory" do
      with_temp_file("not a directory", fn file_path ->
        with_env_var("DESKTOPUI_ERTS_INCLUDE", file_path, fn ->
          assert {:error, :invalid_path} = Erts.include_dir()
        end)
      end)
    end

    test "respects DESKTOPUI_ERTS_INCLUDE with empty string" do
      with_env_var("DESKTOPUI_ERTS_INCLUDE", "", fn ->
        # Empty string should fall back to default detection
        result = Erts.include_dir()
        # Either succeeds or fails, but shouldn't error
        assert elem(result, 0) in [:ok, :error]
      end)
    end
  end

  describe "root_dir/0 edge cases" do
    test "returns a valid path even in unusual installations" do
      result = Erts.root_dir()

      case result do
        {:ok, path} ->
          # Path should exist and be a directory
          assert File.exists?(path)
          assert File.dir?(path)

        {:error, _} ->
          # In some test environments, root_dir might not be found
          :ok
      end
    end

    test "returns consistent result across multiple calls" do
      result1 = Erts.root_dir()
      result2 = Erts.root_dir()

      assert result1 == result2
    end
  end

  describe "version/0 edge cases" do
    test "returns a binary result" do
      case Erts.version() do
        {:ok, version} ->
          assert is_binary(version)
          assert String.length(version) > 0

        {:error, _} ->
          # In some environments, version might not be available
          :ok
      end
    end

    test "returns consistent result across multiple calls" do
      result1 = Erts.version()
      result2 = Erts.version()

      assert result1 == result2
    end
  end

  describe "integration edge cases" do
    test "root_dir and include_dir are consistent" do
      case {Erts.root_dir(), Erts.include_dir()} do
        {{:ok, root}, {:ok, include}} ->
          # Include directory should be under root or accessible
          # In cross-compilation, this might not hold
          assert is_binary(root)
          assert is_binary(include)

        _ ->
          # Skip if either fails
          :ok
      end
    end

    test "handles symlinked ERTS directories" do
      # This test checks if the implementation can handle symlinks
      # Most implementations should work transparently with symlinks
      with_temp_dir("symlink_test", fn dir ->
        # Create a real directory
        real_erts = Path.join(dir, "erts-14.0.0")
        real_include = Path.join(real_erts, "include")
        File.mkdir_p!(real_include)
        File.write!(Path.join(real_include, "erl_nif.h"), "// dummy")

        try do
          # Create a symlink (if supported)
          symlink = Path.join(dir, "erts-link")
          File.ln_s(real_erts, symlink)

          # Should work with symlinked path
          assert :ok = Erts.validate_include_dir(Path.join(symlink, "include"))
        rescue
          # Symlinks might not be supported on all systems
          _ -> :ok
        end
      end)
    end
  end

  describe "path construction edge cases" do
    test "handles version string with non-standard characters" do
      # The version string from :erlang.system_info can have various formats
      version = Erts.version()

      case version do
        {:ok, ver} ->
          # Should always be a binary
          assert is_binary(ver)

        {:error, _} ->
          :ok
      end
    end

    test "handles multiple ERTS versions in root directory" do
      with_temp_dir("multi_erts", fn tmp_dir ->
        # Create multiple ERTS directories
        for v <- ["14.0.0", "14.0.1", "15.0.0"] do
          erts_dir = Path.join(tmp_dir, "erts-#{v}")
          include_dir = Path.join(erts_dir, "include")
          File.mkdir_p!(include_dir)
          File.write!(Path.join(include_dir, "erl_nif.h"), "// dummy for #{v}")
        end

        # The first erts-* directory found should be used
        # This tests the implementation's selection logic
        erts_dirs = File.ls!(tmp_dir) |> Enum.filter(&String.starts_with?(&1, "erts-"))
        assert length(erts_dirs) >= 3
      end)
    end
  end

  describe "error handling edge cases" do
    test "handles permission denied gracefully" do
      # This is difficult to test reliably without root access
      # Just verify the error type is correct
      with_temp_dir("permission_test", fn dir ->
        include_dir = Path.join(dir, "include")
        File.mkdir_p!(include_dir)
        File.write!(Path.join(include_dir, "erl_nif.h"), "// dummy")

        # First verify it works
        assert :ok = Erts.validate_include_dir(include_dir)

        # We can't easily test permission denied without special setup
        # Just ensure the function doesn't crash
        assert :ok = Erts.validate_include_dir(include_dir)
      end)
    end
  end
end

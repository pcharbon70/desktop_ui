defmodule DesktopUI.NifLoaderTest do
  use ExUnit.Case
  alias DesktopUI.NifLoader

  describe "priv_dir/0" do
    test "returns a string" do
      result = NifLoader.priv_dir()
      assert is_binary(result)
    end

    test "returns a path that ends with priv" do
      result = NifLoader.priv_dir()
      assert Path.basename(result) == "priv"
    end

    test "returns an absolute path" do
      result = NifLoader.priv_dir()
      # Check if path is absolute by comparing with its absolute version
      assert result == Path.absname(result) or String.starts_with?(result, "/")
    end

    test "returns consistent path across calls" do
      result1 = NifLoader.priv_dir()
      result2 = NifLoader.priv_dir()
      assert result1 == result2
    end
  end

  describe "nif_extension/0" do
    test "returns a string starting with dot" do
      result = NifLoader.nif_extension()
      assert is_binary(result)
      assert String.starts_with?(result, ".")
    end

    test "returns valid extension for current platform" do
      result = NifLoader.nif_extension()
      assert result in [".so", ".dylib", ".dll"]
    end

    test "returns consistent extension across calls" do
      result1 = NifLoader.nif_extension()
      result2 = NifLoader.nif_extension()
      assert result1 == result2
    end

    test "returns .so on Linux" do
      case DesktopUI.Nif.Platform.detect_platform() do
        {:unix, :linux} ->
          assert NifLoader.nif_extension() == ".so"

        _ ->
          # Skip test on non-Linux platforms
          :ok
      end
    end

    test "returns .dylib on macOS" do
      case DesktopUI.Nif.Platform.detect_platform() do
        {:unix, :darwin} ->
          assert NifLoader.nif_extension() == ".dylib"

        _ ->
          # Skip test on non-macOS platforms
          :ok
      end
    end
  end

  describe "target_triple/0" do
    test "returns a string" do
      result = NifLoader.target_triple()
      assert is_binary(result)
    end

    test "contains multiple components separated by dashes" do
      result = NifLoader.target_triple()
      parts = String.split(result, "-")
      assert length(parts) >= 3
    end

    test "returns consistent target triple across calls" do
      result1 = NifLoader.target_triple()
      result2 = NifLoader.target_triple()
      assert result1 == result2
    end

    test "respects DESKTOPUI_TARGET environment variable" do
      System.put_env("DESKTOPUI_TARGET", "x86_64-test-none")
      result = NifLoader.target_triple()
      System.delete_env("DESKTOPUI_TARGET")

      assert result == "x86_64-test-none"
    end
  end

  describe "nif_path/0" do
    test "returns nil when NIF file does not exist" do
      # This test assumes NIF hasn't been compiled
      # Skip if NIF actually exists
      priv = NifLoader.priv_dir()
      ext = NifLoader.nif_extension()
      standard_path = Path.join(priv, "desktop_ui_nif#{ext}")

      if File.exists?(standard_path) do
        :skip
      else
        result = NifLoader.nif_path()
        # If no NIF exists, should return nil
        assert result in [nil, standard_path]
      end
    end

    test "returns standard path when NIF exists in priv" do
      # Create a temporary NIF file for testing
      priv = NifLoader.priv_dir()
      ext = NifLoader.nif_extension()
      filename = "desktop_ui_nif#{ext}"
      test_path = Path.join(priv, filename)

      # Ensure priv directory exists
      File.mkdir_p!(priv)

      try do
        # Create a temporary file
        File.write!(test_path, "")

        result = NifLoader.nif_path()
        assert result == test_path
      after
        # Clean up
        File.rm(test_path)
      end
    end

    test "returns native path when NIF exists in priv/native" do
      priv = NifLoader.priv_dir()
      ext = NifLoader.nif_extension()
      filename = "desktop_ui_nif#{ext}"
      native_dir = Path.join(priv, "native")
      test_path = Path.join(native_dir, filename)

      File.mkdir_p!(native_dir)

      try do
        File.write!(test_path, "")

        result = NifLoader.nif_path()
        assert result == test_path
      after
        File.rm(test_path)
        File.rmdir(native_dir)
      end
    end

    test "returns prebuilt path when NIF exists in priv/prebuilt" do
      priv = NifLoader.priv_dir()
      ext = NifLoader.nif_extension()
      filename = "desktop_ui_nif#{ext}"
      target = NifLoader.target_triple()
      prebuilt_dir = Path.join([priv, "prebuilt", target])
      test_path = Path.join(prebuilt_dir, filename)

      File.mkdir_p!(prebuilt_dir)

      try do
        File.write!(test_path, "")

        result = NifLoader.nif_path()
        assert result == test_path
      after
        File.rm(test_path)
        File.rmdir(prebuilt_dir)
        # Clean up parent directories if empty
        File.rmdir(Path.join([priv, "prebuilt"]))
        rescue
          _ -> :ok
      end
    end

    test "prefers standard path over native path" do
      priv = NifLoader.priv_dir()
      ext = NifLoader.nif_extension()
      filename = "desktop_ui_nif#{ext}"
      standard_path = Path.join(priv, filename)
      native_dir = Path.join(priv, "native")
      native_path = Path.join(native_dir, filename)

      File.mkdir_p!(native_dir)

      try do
        # Create both files
        File.write!(standard_path, "")
        File.write!(native_path, "")

        result = NifLoader.nif_path()
        # Should prefer standard path
        assert result == standard_path
      after
        File.rm(standard_path)
        File.rm(native_path)
        File.rmdir(native_dir)
      end
    end

    test "prefers standard path over prebuilt path" do
      priv = NifLoader.priv_dir()
      ext = NifLoader.nif_extension()
      filename = "desktop_ui_nif#{ext}"
      standard_path = Path.join(priv, filename)
      target = NifLoader.target_triple()
      prebuilt_dir = Path.join([priv, "prebuilt", target])
      prebuilt_path = Path.join(prebuilt_dir, filename)

      File.mkdir_p!(prebuilt_dir)

      try do
        # Create both files
        File.write!(standard_path, "")
        File.write!(prebuilt_path, "")

        result = NifLoader.nif_path()
        # Should prefer standard path
        assert result == standard_path
      after
        File.rm(standard_path)
        File.rm(prebuilt_path)
        File.rmdir(prebuilt_dir)
        File.rmdir(Path.join([priv, "prebuilt"]))
        rescue
          _ -> :ok
      end
    end
  end

  describe "load_nif/0" do
    test "returns {:error, :not_found} when NIF does not exist" do
      # Ensure no NIF exists
      priv = NifLoader.priv_dir()
      ext = NifLoader.nif_extension()
      standard_path = Path.join(priv, "desktop_ui_nif#{ext}")
      native_path = Path.join([priv, "native", "desktop_ui_nif#{ext}"])

      if File.exists?(standard_path) or File.exists?(native_path) do
        :skip
      else
        result = NifLoader.load_nif()
        assert {:error, :not_found} = result
      end
    end

    test "attempts to load from standard location when NIF exists" do
      priv = NifLoader.priv_dir()
      ext = NifLoader.nif_extension()
      filename = "desktop_ui_nif#{ext}"
      test_path = Path.join(priv, filename)

      File.mkdir_p!(priv)

      try do
        # Create a fake NIF file (not a valid NIF, but exists)
        File.write!(test_path, "")

        # This will fail to load as not a real NIF, but should attempt it
        result = NifLoader.load_nif()

        # Should get either :ok (if NIF was already loaded) or error
        case result do
          :ok -> :ok
          {:error, :not_found} -> :ok
          {:error, {:load_failed, _}} -> :ok
          _ -> flunk("Unexpected result: #{inspect(result)}")
        end
      after
        File.rm(test_path)
      end
    end
  end

  describe "load_nif/1" do
    test "returns {:error, :not_found} for non-existent path" do
      result = NifLoader.load_nif("/nonexistent/path/to/nif.so")
      assert {:error, :not_found} = result
    end

    test "returns {:error, :not_found} for empty string path" do
      result = NifLoader.load_nif("")
      assert {:error, :not_found} = result
    end

    test "attempts to load when file exists at custom path" do
      # Create a temporary file for testing
      temp_dir = System.tmp_dir!()
      ext = NifLoader.nif_extension()
      test_path = Path.join(temp_dir, "test_nif#{ext}")

      try do
        File.write!(test_path, "")

        # This will fail to load as not a valid NIF
        result = NifLoader.load_nif(test_path)

        # Should get either :ok (if somehow loaded) or error
        case result do
          :ok -> :ok
          {:error, {:load_failed, _}} -> :ok
          _ -> flunk("Unexpected result: #{inspect(result)}")
        end
      after
        File.rm(test_path)
      end
    end

    test "accepts relative paths" do
      # Use a relative path that doesn't exist
      result = NifLoader.load_nif("./relative/path/nif.so")
      assert {:error, :not_found} = result
    end
  end

  describe "integration" do
    test "priv_dir and nif_extension are compatible" do
      priv = NifLoader.priv_dir()
      ext = NifLoader.nif_extension()

      assert is_binary(priv)
      assert is_binary(ext)

      # Can combine them without errors
      combined = Path.join(priv, "test#{ext}")
      assert String.contains?(combined, ext)
    end

    test "nif_path returns absolute path or nil" do
      result = NifLoader.nif_path()

      if result != nil do
        assert is_binary(result)
        # Should be an absolute path
        assert Path.absname?(result) or String.starts_with?(result, "/")
        assert String.contains?(result, ".so") or
               String.contains?(result, ".dylib") or
               String.contains?(result, ".dll")
      end
    end

    test "target_triple and nif_extension are consistent" do
      target = NifLoader.target_triple()
      ext = NifLoader.nif_extension()

      cond do
        String.contains?(target, "linux") ->
          assert ext == ".so"

        String.contains?(target, "macos") ->
          assert ext == ".dylib"

        String.contains?(target, "windows") ->
          assert ext == ".dll"

        true ->
          # Unknown platform, accept any
          assert true
      end
    end
  end
end

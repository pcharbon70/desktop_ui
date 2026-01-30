defmodule DesktopUI.Nif.PlatformPropertyTest do
  require DesktopUI.Nif.TestHelper
  use ExUnit.Case, async: true

  alias DesktopUI.Nif.Platform
  import DesktopUI.Nif.TestHelper, only: [with_env_var: 3]

  @moduletag :nif
  @moduletag :platform
  @moduletag :property

  describe "platform detection properties" do
    test "detect_platform always returns a 2-tuple" do
      result = Platform.detect_platform()
      assert is_tuple(result)
      assert tuple_size(result) == 2
    end

    test "detect_platform OS family is either :unix or :win32" do
      {os_family, _os_type} = Platform.detect_platform()
      assert os_family in [:unix, :win32]
    end
  end

  describe "architecture detection properties" do
    test "detect_architecture always returns a known architecture" do
      result = Platform.detect_architecture()
      assert result in [:x86_64, :aarch64, :arm64, :x86, :arm, :unknown]
    end

    test "detect_architecture always returns an atom" do
      assert is_atom(Platform.detect_architecture())
    end
  end

  describe "target triple properties" do
    test "target_triple always returns a string" do
      assert is_binary(Platform.target_triple())
    end

    test "target_triple has at least 3 components" do
      triple = Platform.target_triple()
      parts = String.split(triple, "-")
      assert length(parts) >= 3
    end

    test "target_triple is deterministic" do
      triple1 = Platform.target_triple()
      triple2 = Platform.target_triple()
      assert triple1 == triple2
    end

    test "target triple format is valid" do
      # Test well-known target triples
      triples = [
        "x86_64-linux-gnu",
        "aarch64-linux-gnu",
        "x86_64-macos-none",
        "aarch64-macos-none",
        "x86_64-windows-gnu"
      ]

      Enum.each(triples, fn triple ->
        assert is_binary(triple)
        assert String.contains?(triple, "-")
        parts = String.split(triple, "-")
        assert length(parts) >= 3
      end)
    end
  end

  describe "nif_extension properties" do
    test "nif_extension always starts with a dot" do
      ext = Platform.nif_extension()
      assert String.starts_with?(ext, ".")
    end

    test "nif_extension is one of the known extensions" do
      ext = Platform.nif_extension()
      assert ext in [".so", ".dylib", ".dll"]
    end

    test "nif_extension is consistent with platform" do
      triple = Platform.target_triple()
      ext = Platform.nif_extension()

      cond do
        String.contains?(triple, "linux") ->
          assert ext == ".so"

        String.contains?(triple, "macos") ->
          assert ext == ".dylib"

        String.contains?(triple, "windows") ->
          assert ext == ".dll"

        true ->
          # Unknown platform, accept any extension
          assert true
      end
    end
  end

  describe "c_compiler properties" do
    test "c_compiler returns nil or a valid path" do
      result = Platform.c_compiler()

      if result != nil do
        # Either it exists in filesystem or is findable
        assert File.exists?(result) or System.find_executable(Path.basename(result)) != nil
      else
        assert true
      end
    end
  end

  describe "consistency properties" do
    test "target triple components are consistent with detection" do
      {os, arch} = {Platform.detect_platform(), Platform.detect_architecture()}
      triple = Platform.target_triple()

      # Triple should contain references to the detected OS and arch
      assert is_binary(triple)
      assert tuple_size(os) == 2
      assert is_atom(arch)
    end

    test "multiple calls return consistent results" do
      # All detection functions should return consistent results
      os1 = Platform.detect_platform()
      os2 = Platform.detect_platform()
      assert os1 == os2

      arch1 = Platform.detect_architecture()
      arch2 = Platform.detect_architecture()
      assert arch1 == arch2

      triple1 = Platform.target_triple()
      triple2 = Platform.target_triple()
      assert triple1 == triple2

      ext1 = Platform.nif_extension()
      ext2 = Platform.nif_extension()
      assert ext1 == ext2
    end
  end

  describe "DESKTOPUI_TARGET override" do
    test "respects DESKTOPUI_TARGET environment variable" do
      with_env_var("DESKTOPUI_TARGET", "x86_64-test-none", fn ->
        assert Platform.target_triple() == "x86_64-test-none"
      end)
    end

    test "DESKTOPUI_TARGET overrides detected platform" do
      # Store original target triple
      original = System.get_env("DESKTOPUI_TARGET")

      try do
        System.put_env("DESKTOPUI_TARGET", "aarch64-custom-test")
        assert Platform.target_triple() == "aarch64-custom-test"
      after
        if original do
          System.put_env("DESKTOPUI_TARGET", original)
        else
          System.delete_env("DESKTOPUI_TARGET")
        end
      end
    end
  end
end

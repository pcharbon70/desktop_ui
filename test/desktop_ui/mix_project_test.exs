defmodule DesktopUi.MixProjectTest do
  use ExUnit.Case

  alias DesktopUi.MixProject

  describe "project/0" do
    test "returns expected project configuration" do
      project = MixProject.project()

      assert is_list(project)
      assert Keyword.has_key?(project, :app)
      assert Keyword.has_key?(project, :version)
      assert Keyword.has_key?(project, :elixir)
      assert Keyword.has_key?(project, :compilers)
      assert Keyword.has_key?(project, :deps)
      assert Keyword.has_key?(project, :nif_opts)
      assert Keyword.has_key?(project, :aliases)
    end

    test "includes :desktop_ui_nif in compilers when not skipped" do
      System.delete_env("DESKTOPUI_SKIP_NIF")

      project = MixProject.project()
      compilers = Keyword.get(project, :compilers)

      assert :desktop_ui_nif in compilers
      assert :elixir in compilers
    end

    test "excludes :desktop_ui_nif when DESKTOPUI_SKIP_NIF is set" do
      System.put_env("DESKTOPUI_SKIP_NIF", "1")

      project = MixProject.project()
      compilers = Keyword.get(project, :compilers)

      System.delete_env("DESKTOPUI_SKIP_NIF")

      refute :desktop_ui_nif in compilers
      assert :elixir in compilers
    end

    test "nif_compiler runs before elixir compiler" do
      System.delete_env("DESKTOPUI_SKIP_NIF")

      project = MixProject.project()
      compilers = Keyword.get(project, :compilers)

      nif_index = Enum.find_index(compilers, &(&1 == :desktop_ui_nif))
      elixir_index = Enum.find_index(compilers, &(&1 == :elixir))

      assert nif_index != nil
      assert elixir_index != nil
      assert nif_index < elixir_index
    end
  end

  describe "nif_opts" do
    test "are included in project configuration" do
      project = MixProject.project()
      opts = Keyword.get(project, :nif_opts)

      assert is_list(opts)
      assert Keyword.keyword?(opts)
    end

    test "includes expected keys" do
      project = MixProject.project()
      opts = Keyword.get(project, :nif_opts)

      expected_keys = [:target, :skip, :erts_include_dir, :sdl2_cflags, :sdl2_ldflags]
      Enum.each(expected_keys, fn key ->
        assert Keyword.has_key?(opts, key), "Missing key: #{key}"
      end)
    end

    test "respects DESKTOPUI_TARGET environment variable" do
      System.put_env("DESKTOPUI_TARGET", "x86_64-windows-gnu")

      project = MixProject.project()
      opts = Keyword.get(project, :nif_opts)

      System.delete_env("DESKTOPUI_TARGET")

      assert Keyword.get(opts, :target) == "x86_64-windows-gnu"
    end

    test "target is nil when DESKTOPUI_TARGET is not set" do
      System.delete_env("DESKTOPUI_TARGET")

      project = MixProject.project()
      opts = Keyword.get(project, :nif_opts)

      assert Keyword.get(opts, :target) == nil
    end

    test "skip is true when DESKTOPUI_SKIP_NIF is set" do
      System.put_env("DESKTOPUI_SKIP_NIF", "1")

      project = MixProject.project()
      opts = Keyword.get(project, :nif_opts)

      System.delete_env("DESKTOPUI_SKIP_NIF")

      assert Keyword.get(opts, :skip) == true
    end

    test "skip is false when DESKTOPUI_SKIP_NIF is not set" do
      System.delete_env("DESKTOPUI_SKIP_NIF")

      project = MixProject.project()
      opts = Keyword.get(project, :nif_opts)

      assert Keyword.get(opts, :skip) == false
    end

    test "respects ERTS_INCLUDE_DIR environment variable" do
      System.put_env("ERTS_INCLUDE_DIR", "/custom/erts/include")

      project = MixProject.project()
      opts = Keyword.get(project, :nif_opts)

      System.delete_env("ERTS_INCLUDE_DIR")

      assert Keyword.get(opts, :erts_include_dir) == "/custom/erts/include"
    end

    test "respects SDL2_CFLAGS environment variable" do
      System.put_env("SDL2_CFLAGS", "-I/custom/sdl2/include")

      project = MixProject.project()
      opts = Keyword.get(project, :nif_opts)

      System.delete_env("SDL2_CFLAGS")

      assert Keyword.get(opts, :sdl2_cflags) == "-I/custom/sdl2/include"
    end

    test "respects SDL2_LDFLAGS environment variable" do
      System.put_env("SDL2_LDFLAGS", "-L/custom/sdl2/lib -lSDL2")

      project = MixProject.project()
      opts = Keyword.get(project, :nif_opts)

      System.delete_env("SDL2_LDFLAGS")

      assert Keyword.get(opts, :sdl2_ldflags) == "-L/custom/sdl2/lib -lSDL2"
    end
  end

  describe "aliases" do
    test "are included in project configuration" do
      project = MixProject.project()
      aliases = Keyword.get(project, :aliases)

      assert is_list(aliases)
      assert Keyword.keyword?(aliases)
    end

    test "includes nif_compile alias" do
      project = MixProject.project()
      aliases = Keyword.get(project, :aliases)

      assert Keyword.has_key?(aliases, :nif_compile)
    end

    test "nif_compile alias points to compile.desktop_ui_nif" do
      project = MixProject.project()
      aliases = Keyword.get(project, :aliases)

      assert Keyword.get(aliases, :nif_compile) == ["compile.desktop_ui_nif"]
    end

    test "includes nif_clean alias" do
      project = MixProject.project()
      aliases = Keyword.get(project, :aliases)

      assert Keyword.has_key?(aliases, :nif_clean)
    end

    test "nif_clean alias points to clean.desktop_ui_nif" do
      project = MixProject.project()
      aliases = Keyword.get(project, :aliases)

      assert Keyword.get(aliases, :nif_clean) == ["clean.desktop_ui_nif"]
    end
  end

  describe "integration" do
    test "project configuration is valid" do
      project = MixProject.project()

      # Verify the project can be used by Mix
      assert Keyword.get(project, :app) == :desktop_ui
      assert Keyword.get(project, :version) == "0.1.0"
      assert Keyword.get(project, :elixir) =~ ~r/~> 1\.18/
    end

    test "compilers list is valid" do
      project = MixProject.project()
      compilers = Keyword.get(project, :compilers)

      assert is_list(compilers)
      Enum.each(compilers, fn compiler ->
        assert is_atom(compiler)
      end)
    end

    test "deps list is valid" do
      project = MixProject.project()
      deps = Keyword.get(project, :deps)

      assert is_list(deps)
      assert length(deps) >= 2
    end
  end
end

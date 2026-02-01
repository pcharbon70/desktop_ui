defmodule Mix.Tasks.Compile.DesktopUiNif do
  @moduledoc """
  Mix compiler task for building the DesktopUI NIF.

  This compiler integrates NIF compilation into the standard `mix compile` workflow.
  It supports both Zig (preferred) and Makefile as build methods, with automatic
  fallback and explicit selection options.

  ## Compiler Selection

  The compiler selection strategy is:
  1. If `DESKTOPUI_PREFER_COMPILER` is set, use that compiler (zig/makefile/none)
  2. Otherwise, try Zig first if available and version-compatible
  3. Fall back to Makefile if Zig is unavailable
  4. Return error if both compilers are unavailable

  ## Environment Variables

  * `DESKTOPUI_SKIP_NIF` - Set to "1" to skip NIF compilation
  * `DESKTOPUI_TARGET` - Target triple for cross-compilation (e.g., x86_64-windows-gnu)
  * `DESKTOPUI_PREFER_COMPILER` - Force specific compiler: "zig", "makefile", or "none"
  * `ERTS_INCLUDE_DIR` - Override ERTS include directory detection
  * `SDL2_CFLAGS` - Override SDL2 C compiler flags
  * `SDL2_LDFLAGS` - Override SDL2 linker flags

  ## Examples

      # Default compilation (Zig preferred, Makefile fallback)
      mix compile

      # Force Zig compiler
      DESKTOPUI_PREFER_COMPILER=zig mix compile

      # Force Makefile compiler
      DESKTOPUI_PREFER_COMPILER=makefile mix compile

      # Skip NIF compilation
      DESKTOPUI_SKIP_NIF=1 mix compile

      # Cross-compile for Windows
      DESKTOPUI_TARGET=x86_64-windows-gnu mix compile

  """

  use Mix.Task.Compiler

  @recursive false

  @impl true
  def run(_args) do
    if should_compile?() do
      compile_nif()
    else
      {:noop, []}
    end
  end

  @impl true
  def clean do
    # Remove NIF artifacts from priv directory
    priv_dir = Path.join(Mix.Project.app_path(), "priv")

    # Remove all NIF files with any extension
    nif_files = Path.wildcard(Path.join(priv_dir, "desktop_ui_nif.*"))
    Enum.each(nif_files, &File.rm/1)

    # Also remove any .o files
    o_files = Path.wildcard(Path.join(priv_dir, "*.o"))
    Enum.each(o_files, &File.rm/1)

    :ok
  end

  @impl true
  def manifests do
    # Return manifest paths for incremental compilation support
    [manifest_path()]
  end

  # Private Functions

  defp compile_nif do
    # Get ERTS include directory and target
    with {:ok, erts_include} <- get_erts_include(),
         {:ok, target} <- get_target() do
      # Choose compiler based on preference and availability
      case choose_compiler() do
        {:ok, :zig} ->
          compile_with_zig(erts_include, target, [])

        {:ok, :makefile} ->
          compile_with_makefile(erts_include, target, [log: true])

        {:ok, :none} ->
          # Explicitly skipped via DESKTOPUI_PREFER_COMPILER=none
          Mix.shell().info([
            :cyan,
            "NIF compilation skipped (DESKTOPUI_PREFER_COMPILER=none)"
          ])

          {:noop, []}

        {:error, :no_compiler_available} ->
          # No compiler available
          diagnostic = %{
            compiler_name: "desktop_ui_nif",
            message: "No compiler available. Please install Zig (recommended) or make.",
            position: nil,
            file: nil,
            severity: :error
          }

          {:error, [diagnostic]}
      end
    else
      {:error, {:invalid_target, message}} ->
        # Invalid target triple - provide helpful error
        diagnostic = %{
          compiler_name: "desktop_ui_nif",
          message: message,
          position: nil,
          file: nil,
          severity: :error
        }

        {:error, [diagnostic]}

      {:error, reason} ->
        # Other error
        diagnostic = %{
          compiler_name: "desktop_ui_nif",
          message: "NIF compilation failed: #{inspect(reason)}",
          position: nil,
          file: "desktop_ui_nif",
          severity: :error
        }

        {:error, [diagnostic]}
    end
  end

  defp compile_with_makefile(erts_include, target, opts) do
    # Find make executable
    log_selection = Keyword.get(opts, :log, true)

    if log_selection do
      log_makefile_selection()
    end

    case find_make_executable() do
      {:ok, make} ->
        # Prepare environment variables
        # Pass target to SDL2 functions for cross-compilation detection
        is_cross_compile = target != DesktopUI.Nif.Platform.target_triple()
        sdl2_cflags = DesktopUI.Nif.SDL2.cflags(if is_cross_compile, do: target, else: nil)
        sdl2_ldflags = DesktopUI.Nif.SDL2.ldflags(if is_cross_compile, do: target, else: nil)

        env = [
          {"ERTS_INCLUDE_DIR", erts_include},
          {"DESKTOPUI_TARGET", target},
          {"SDL2_CFLAGS", Enum.join(sdl2_cflags, " ")},
          {"SDL2_LDFLAGS", Enum.join(sdl2_ldflags, " ")}
        ]

        # Run make with environment variables
        {output, exit_code} = System.cmd(make, ["all"], env: env, cd: Mix.Project.build_path())

        case exit_code do
          0 ->
            # Success - write manifest
            write_manifest()
            {:ok, []}

          2 ->
            # Compilation error
            diagnostic = %{
              compiler_name: "desktop_ui_nif",
              message: "NIF compilation failed:\n#{output}",
              position: nil,
              file: "make",
              severity: :error
            }

            {:error, [diagnostic]}

          _ ->
            # Other error
            diagnostic = %{
              compiler_name: "desktop_ui_nif",
              message: "make exited with code #{exit_code}:\n#{output}",
              position: nil,
              file: "make",
              severity: :error
            }

            {:error, [diagnostic]}
        end

      {:error, :not_found} ->
        # make not found
        Mix.shell().info([
          :yellow,
          "make not found. Skipping NIF compilation."
        ])

        diagnostic = %{
          compiler_name: "desktop_ui_nif",
          message: "make executable not found. Please install make to compile the NIF.",
          position: nil,
          file: nil,
          severity: :warning
        }

        {:ok, [], [diagnostic]}

      {:error, reason} ->
        diagnostic = %{
          compiler_name: "desktop_ui_nif",
          message: "Failed to find make: #{inspect(reason)}",
          position: nil,
          file: nil,
          severity: :error
        }

        {:error, [diagnostic]}
    end
  end

  defp find_make_executable do
    # Try to find make or mingw32-make (Windows MSYS2)
    case System.find_executable("make") do
      nil ->
        # Try mingw32-make for Windows
        case System.find_executable("mingw32-make") do
          nil -> {:error, :not_found}
          path -> {:ok, path}
        end

      path ->
        {:ok, path}
    end
  end

  defp get_erts_include do
    case DesktopUI.Nif.Erts.include_dir() do
      {:ok, path} -> {:ok, path}
      {:error, reason} -> {:error, {:erts_not_found, reason}}
    end
  end

  defp get_target do
    case System.get_env("DESKTOPUI_TARGET") do
      nil ->
        # No override - use native target
        {:ok, DesktopUI.Nif.Platform.target_triple()}

      target ->
        # Validate the target triple
        case validate_target(target) do
          :ok ->
            {:ok, target}

          {:error, reason} ->
            # Target is invalid - return helpful error
            {:error, {:invalid_target, format_target_error(target, reason)}}
        end
    end
  end

  defp should_compile? do
    # Check DESKTOPUI_SKIP_NIF environment variable
    # Any value set means skip NIF compilation
    System.get_env("DESKTOPUI_SKIP_NIF") == nil
  end

  # Manifest functions for incremental compilation

  defp manifest_path do
    Path.join(Mix.Project.build_path(), ".desktop_ui_nif_manifest")
  end

  defp write_manifest do
    manifest = manifest_path()

    # Write manifest with current timestamp and compilation info
    info = %{
      compiled_at: System.system_time(:second),
      erts_version: elem(DesktopUI.Nif.Erts.version(), 1),
      target: elem(get_target(), 1)
    }

    File.write!(manifest, :erlang.term_to_binary(info))
  end

  # Zig Compilation Functions

  defp compile_with_zig(erts_include, target, _opts) do
    # Find Zig executable and check version
    with {:ok, zig_path} <- DesktopUI.Nif.Zig.find_executable(),
         {:ok, zig_version} <- DesktopUI.Nif.Zig.version(),
         :ok <- DesktopUI.Nif.Zig.check_version(zig_version),
         {:ok, zig_target} <- map_target_for_zig(target) do
      # All checks passed, compile with Zig
      Mix.shell().info([
        :cyan,
        "Compiling NIF with Zig #{zig_version} (target: #{zig_target})"
      ])

      # Build Zig command
      output_path = get_output_path(target)
      zig_cmd = build_zig_command(zig_path, zig_target, erts_include, output_path)

      # Run Zig compilation
      {output, exit_code} = System.cmd(zig_path, zig_cmd, cd: Mix.Project.build_path())

      case exit_code do
        0 ->
          # Success - write manifest
          write_manifest()
          {:ok, []}

        _ ->
          # Compilation error
          diagnostic = %{
            compiler_name: "desktop_ui_nif",
            message: "Zig compilation failed:\n#{output}",
            position: nil,
            file: "zig",
            severity: :error
          }

          {:error, [diagnostic]}
      end
    else
      {:error, :not_found} ->
        # Zig not found
        Mix.shell().info([
          :yellow,
          "Zig not found. Falling back to Makefile."
        ])

        # Try fallback to Makefile
        case find_make_executable() do
          {:ok, _make} ->
            compile_with_makefile(erts_include, target, [log: false])

          {:error, :not_found} ->
            diagnostic = %{
              compiler_name: "desktop_ui_nif",
              message: "No compiler available. Please install Zig (recommended) or make.",
              position: nil,
              file: nil,
              severity: :error
            }

            {:error, [diagnostic]}
        end

      {:error, :incompatible_version} ->
        # Zig version incompatible
        Mix.shell().info([
          :yellow,
          "Zig version incompatible. Falling back to Makefile."
        ])

        # Try fallback to Makefile
        case find_make_executable() do
          {:ok, _make} ->
            compile_with_makefile(erts_include, target, [log: false])

          {:error, :not_found} ->
            diagnostic = %{
              compiler_name: "desktop_ui_nif",
              message: "Zig version incompatible and make not found. Please install Zig #{DesktopUI.Nif.Zig.minimum_version()} or later.",
              position: nil,
              file: nil,
              severity: :error
            }

            {:error, [diagnostic]}
        end

      {:error, :unknown_target} ->
        diagnostic = %{
          compiler_name: "desktop_ui_nif",
          message: "Unknown target for Zig: #{target}",
          position: nil,
          file: "zig",
          severity: :error
        }

        {:error, [diagnostic]}
    end
  end

  defp map_target_for_zig(target) do
    # Our target triples are already compatible with Zig
    # Just validate that it's a known target format
    case target do
      t when t in [
        "x86_64-linux-gnu",
        "aarch64-linux-gnu",
        "x86_64-macos-none",
        "aarch64-macos-none",
        "x86_64-windows-gnu"
      ] ->
        {:ok, target}

      _ ->
        # For unknown targets, try to use them anyway
        # Zig might support targets we don't know about
        {:ok, target}
    end
  end

  defp build_zig_command(zig_path, target, erts_include, output_path) do
    # Get SDL2 flags
    # Determine if this is cross-compilation
    native_target = DesktopUI.Nif.Platform.target_triple()
    is_cross_compile = target != native_target
    sdl2_target = if is_cross_compile, do: target, else: nil

    sdl2_cflags = DesktopUI.Nif.SDL2.cflags(sdl2_target)
    sdl2_ldflags = DesktopUI.Nif.SDL2.ldflags(sdl2_target)

    # Build command arguments
    # zig cc -target {target} -O2 -fPIC -shared -I {erts} {sdl2_cflags} {source} -o {output} {sdl2_ldflags}
    base_args = [
      "cc",
      "-target", target,
      "-O2",
      "-fPIC",
      "-shared",
      "-I", erts_include
    ]

    # Add SDL2 cflags (each as separate argument if they contain spaces)
    cflag_args = Enum.flat_map(sdl2_cflags, fn flag ->
      String.split(flag, " ", trim: true)
    end)

    # Source files
    source_files = Path.wildcard("c_src/*.c")

    # Output
    output_args = ["-o", output_path]

    # Add SDL2 ldflags
    ldflag_args = Enum.flat_map(sdl2_ldflags, fn flag ->
      String.split(flag, " ", trim: true)
    end)

    # Combine all arguments
    base_args ++ cflag_args ++ source_files ++ output_args ++ ldflag_args
  end

  defp get_output_path do
    get_output_path(nil)
  end

  defp get_output_path(target) do
    priv_dir = Path.join(Mix.Project.app_path(), "priv")
    extension = DesktopUI.Nif.Platform.nif_extension()

    # For cross-compilation, include target in filename
    # For native builds, use simple naming
    case target do
      nil ->
        # Native build - use simple naming
        Path.join(priv_dir, "desktop_ui_nif#{extension}")

      t ->
        # Cross-compile - include target in filename for clarity
        # Example: desktop_ui_nif.x86_64-windows-gnu.dll
        if is_cross_compile?(t) do
          Path.join(priv_dir, "desktop_ui_nif.#{t}#{extension}")
        else
          # Target matches native platform, use simple naming
          Path.join(priv_dir, "desktop_ui_nif#{extension}")
        end
    end
  end

  # Cross-Compilation Helper Functions

  defp validate_target(target) when is_binary(target) do
    # Validate target triple format: {arch}-{os}-{env}
    case String.split(target, "-", parts: 3) do
      [arch, os, env] ->
        # Check if components are valid
        cond do
          !valid_architecture?(arch) ->
            {:error, {:unknown_architecture, arch}}

          !valid_os?(os) ->
            {:error, {:unknown_os, os}}

          !valid_environment?(env) ->
            {:error, {:unknown_environment, env}}

          true ->
            :ok
        end

      _ ->
        {:error, :invalid_format}
    end
  end

  defp is_cross_compile?(target) do
    # Compare with native target
    native_target = DesktopUI.Nif.Platform.target_triple()
    target != native_target
  end

  defp valid_architecture?(arch) do
    # List of known architectures
    # Be permissive - allow unknown architectures as Zig may support them
    arch in [
      "x86_64", "aarch64", "arm64", "arm", "x86",
      "riscv64", "riscv32", "mips64", "mips",
      "powerpc64le", "powerpc", "s390x", "sparc64"
    ] or Regex.match?(~r/^[a-z0-9_]+$/, arch)
  end

  defp valid_os?(os) do
    # List of known OS names
    # Be permissive - allow unknown OS as Zig may support them
    os in [
      "linux", "macos", "windows", "freebsd", "openbsd",
      "netbsd", "dragonfly", "solaris", "illumos"
    ] or Regex.match?(~r/^[a-z0-9_]+$/, os)
  end

  defp valid_environment?(env) do
    # List of known environments
    # Be permissive - allow unknown environments as Zig may support them
    env in [
      "gnu", "gnueabi", "gnueabihf", "musl", "musleabi", "musleabihf",
      "none", "eabi", "eabihf", "android"
    ] or Regex.match?(~r/^[a-z0-9_]+$/, env)
  end

  defp format_target_error(target, reason) do
    base_message = "Invalid target triple: \"#{target}\""

    detail_message = case reason do
      :invalid_format ->
        """

        Expected format: {arch}-{os}-{env}
        Example: x86_64-linux-gnu

        The target triple must have exactly three components separated by hyphens.
        """

      {:unknown_architecture, arch} ->
        """

        Unknown architecture: "#{arch}"

        Supported architectures:
        - x86_64, aarch64, arm64, arm, x86
        - riscv64, riscv32, mips64, mips
        - powerpc64le, powerpc, s390x, sparc64

        Or Zig may support additional architectures.
        """

      {:unknown_os, os} ->
        """

        Unknown OS: "#{os}"

        Supported OS:
        - linux, macos, windows
        - freebsd, openbsd, netbsd
        - dragonfly, solaris, illumos

        Or Zig may support additional operating systems.
        """

      {:unknown_environment, env} ->
        """

        Unknown environment: "#{env}"

        Supported environments:
        - gnu, gnueabi, gnueabihf
        - musl, musleabi, musleabihf
        - none, eabi, eabihf, android

        Or Zig may support additional environments.
        """
    end

    base_message <> detail_message
  end

  # Compiler Selection Functions

  defp log_makefile_selection do
    pref = System.get_env("DESKTOPUI_PREFER_COMPILER")

    message = if pref == "makefile" do
      "Compiling NIF with Makefile (DESKTOPUI_PREFER_COMPILER=makefile)"
    else
      # Fallback selection
      "Compiling NIF with Makefile (fallback from Zig)"
    end

    Mix.shell().info([:cyan, message])
  end

  defp choose_compiler do
    case System.get_env("DESKTOPUI_PREFER_COMPILER") do
      "zig" ->
        # Force Zig
        case DesktopUI.Nif.Zig.installed?() do
          true ->
            {:ok, :zig}

          false ->
            # Zig requested but not available - error
            diagnostic = %{
              compiler_name: "desktop_ui_nif",
              message: "Zig compiler requested but not found. #{DesktopUI.Nif.Zig.not_found_error()}",
              position: nil,
              file: nil,
              severity: :error
            }

            {:error, :zig_not_available}
        end

      "makefile" ->
        # Force Makefile
        case find_make_executable() do
          {:ok, _make} ->
            {:ok, :makefile}

          {:error, :not_found} ->
            diagnostic = %{
              compiler_name: "desktop_ui_nif",
              message: "Makefile compiler requested but make not found.",
              position: nil,
              file: nil,
              severity: :error
            }

            {:error, :makefile_not_available}
        end

      "none" ->
        # Explicitly skip compilation
        {:ok, :none}

      nil ->
        # No preference - use default strategy
        choose_compiler_default()

      _other ->
        # Invalid value, warn and use default
        Mix.shell().info([
          :yellow,
          "Invalid DESKTOPUI_PREFER_COMPILER value. Using default compiler selection."
        ])

        choose_compiler_default()
    end
  end

  defp choose_compiler_default do
    # Default strategy: Try Zig first, fall back to Makefile
    case DesktopUI.Nif.Zig.installed?() do
      true ->
        # Check version compatibility
        case DesktopUI.Nif.Zig.version() do
          {:ok, version} ->
            case DesktopUI.Nif.Zig.check_version(version) do
              :ok ->
                # Zig is available and compatible
                {:ok, :zig}

              {:error, :incompatible_version} ->
                # Zig is incompatible, try Makefile
                try_makefile_fallback()
            end

          {:error, :not_found} ->
            # Couldn't get version, try Makefile
            try_makefile_fallback()
        end

      false ->
        # Zig not installed, try Makefile
        try_makefile_fallback()
    end
  end

  defp try_makefile_fallback do
    case find_make_executable() do
      {:ok, _make} ->
        {:ok, :makefile}

      {:error, :not_found} ->
        {:error, :no_compiler_available}
    end
  end
end

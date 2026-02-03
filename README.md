# DesktopUI

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `desktop_ui` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:desktop_ui, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/desktop_ui>.

## Building

DesktopUI includes a native NIF (Native Implemented Function) that requires compilation.

**📖 Detailed build documentation is available in [docs/build/](docs/build/).**

- [Getting Started Guide](docs/build/getting-started.md) - Quick start for your platform
- [Cross-Compilation Guide](docs/build/cross-compilation.md) - Build for other platforms
- [Platform Setup](docs/build/platform-setup/) - Platform-specific prerequisites
- [Troubleshooting](docs/build/troubleshooting.md) - Common issues and solutions
- **[Release Guide](docs/build/release.md)** - Creating distributable releases with bundled SDL2

### Quick Start

DesktopUI uses a **two-step build process**:

1. **Compile Elixir code**: `mix compile`
2. **Build the NIF** (platform-specific):

#### Windows (PowerShell)

```powershell
.\build.ps1
```

#### macOS/Linux

```bash
./build.sh
# or
make -f Makefile
```

The build script handles both steps automatically. See [docs/build/getting-started.md](docs/build/getting-started.md) for detailed platform-specific instructions.

### Manual NIF Compilation

If you need to compile the NIF manually (after Elixir code is already compiled):

```bash
mix compile.desktop_ui_nif
```

Or use the shortcut alias:

```bash
mix nif.compile
```

### Building with Zig

DesktopUI can also be built using Zig directly without Mix. This requires Zig 0.11.0 or later.

#### Prerequisites

1. Install Zig from https://ziglang.org/download
2. Install SDL2 development libraries:
   - **Linux**: `sudo apt-get install libsdl2-dev`
   - **macOS**: `brew install sdl2`
   - **Windows**: Download from https://github.com/libsdl-org/SDL/releases
3. Erlang/OTP must be installed for ERTS headers

#### Native Build

```bash
ERTS_INCLUDE_DIR=$(erl -noshell -eval "io:format('~s/erts-~s/include', [code:root_dir(), erlang:system_info(version)]).") \
zig build
```

#### Cross-Compilation with Zig

Zig provides first-class cross-compilation support via the `-Dtarget` option:

```bash
# Build for ARM64 Linux
ERTS_INCLUDE_DIR=$(erl -noshell -eval "io:format('~s/erts-~s/include', [code:root_dir(), erlang:system_info(version)]).") \
zig build -Dtarget=aarch64-linux-gnu

# Build for Windows
ERTS_INCLUDE_DIR=$(erl -noshell -eval "io:format('~s/erts-~s/include', [code:root_dir(), erlang:system_info(version)]).") \
zig build -Dtarget=x86_64-windows-gnu

# Build for macOS ARM64
ERTS_INCLUDE_DIR=$(erl -noshell -eval "io:format('~s/erts-~s/include', [code:root_dir(), erlang:system_info(version)]).") \
zig build -Dtarget=aarch64-macos-none
```

#### Zig Build Options

| Option | Description |
|---|---|
| `-Dtarget=<triple>` | Target triple for cross-compilation (e.g., `aarch64-linux-gnu`) |
| `-Doptimize=<mode>` | Optimization mode: `Debug`, `ReleaseSafe`, `ReleaseFast`, `ReleaseSmall` |
| `-Derts-include=<path>` | Path to ERTS include directory (overrides `ERTS_INCLUDE_DIR`) |

#### Example: Release Build

```bash
ERTS_INCLUDE_DIR=$(erl -noshell -eval "io:format('~s/erts-~s/include', [code:root_dir(), erlang:system_info(version)]).") \
zig build -Doptimize=ReleaseFast
```

#### Zig Build Steps

- `zig build` - Build and install NIF to `priv/`
- `zig build check` - Build without installing (useful for CI)

## Creating Releases

DesktopUI applications require SDL2 to be distributed with your application. See the [Release Guide](docs/build/release.md) for complete documentation.

### Quick Release

#### Windows

```powershell
.\release.ps1
```

Creates `releases/desktop_ui_v{x.x.x}_windows-x64.zip` with bundled SDL2.dll.

#### Linux/macOS

```bash
./release.sh
```

Creates `releases/desktop_ui_v{x.x.x}_{platform}-{arch}.tar.gz` with bundled SDL2 library.

The release includes:
- NIF library
- SDL2 library (platform-specific)
- Launcher scripts that set library paths
- README with end-user instructions


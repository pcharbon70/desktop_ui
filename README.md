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
The NIF can be built using either Mix (recommended for Elixir projects) or Zig directly
(useful for development and debugging).

### Building with Mix (Recommended)

The NIF is automatically compiled when you run `mix compile`:

```bash
mix compile
```

#### Cross-Compilation with Mix

To cross-compile for a different target platform, set the `DESKTOPUI_TARGET` environment variable:

```bash
# Build for Windows from Linux
DESKTOPUI_TARGET=x86_64-windows-gnu mix compile

# Build for macOS ARM64 from Linux
DESKTOPUI_TARGET=aarch64-macos-none mix compile

# Build for Linux ARM64 from x86_64
DESKTOPUI_TARGET=aarch64-linux-gnu mix compile
```

#### Compiler Selection

By default, Mix tries Zig first and falls back to Makefile. You can force a specific compiler:

```bash
# Force Zig compiler
DESKTOPUI_PREFER_COMPILER=zig mix compile

# Force Makefile compiler
DESKTOPUI_PREFER_COMPILER=makefile mix compile

# Skip NIF compilation entirely
DESKTOPUI_SKIP_NIF=1 mix compile
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


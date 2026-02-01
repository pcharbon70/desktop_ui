# CI/CD Examples

This guide provides examples for setting up automated builds and CI/CD workflows for DesktopUI.

## GitHub Actions

### Basic Multi-Platform Build

Build on multiple platforms in parallel:

```yaml
name: Build

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  build:
    name: Build on ${{ matrix.os }}
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
        include:
          - os: ubuntu-latest
            target: x86_64-linux-gnu
          - os: macos-latest
            target: x86_64-macos-none
          - os: windows-latest
            target: x86_64-windows-gnu

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Install Erlang/Elixir
        uses: erlef/setup-beam@v1
        with:
          otp-version: "27"
          elixir-version: "1.18"

      - name: Install dependencies (Ubuntu)
        if: matrix.os == 'ubuntu-latest'
        run: |
          sudo apt-get update
          sudo apt-get install -y build-essential libsdl2-dev

      - name: Install dependencies (macOS)
        if: matrix.os == 'macos-latest'
        run: |
          brew install sdl2

      - name: Install dependencies (Windows)
        if: matrix.os == 'windows-latest'
        shell: pwsh
        run: |
          choco install zig
          # SDL2 via MSYS2 or manual

      - name: Install Zig
        uses: goto-bus-stop/setup-zig@v2
        with:
          version: 0.11.0

      - name: Fetch dependencies
        run: mix deps.get

      - name: Compile
        run: mix compile
        env:
          DESKTOPUI_PREFER_COMPILER: zig
          DESKTOPUI_TARGET: ${{ matrix.target }}

      - name: Run tests
        run: mix test

      - name: Upload NIF artifact
        uses: actions/upload-artifact@v4
        with:
          name: nif-${{ matrix.os }}
          path: priv/desktop_ui_nif.so
```

### Cross-Compilation Matrix

Build for multiple targets from a single runner:

```yaml
name: Cross-Compile

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  cross-compile:
    name: Build for ${{ matrix.target }}
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        target:
          - x86_64-linux-gnu
          - x86_64-linux-musl
          - aarch64-linux-gnu
          - x86_64-macos-none
          - aarch64-macos-none
          - x86_64-windows-gnu

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Install Erlang/Elixir
        uses: erlef/setup-beam@v1
        with:
          otp-version: "27"
          elixir-version: "1.18"

      - name: Install build dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y build-essential libsdl2-dev

      - name: Install Zig
        uses: goto-bus-stop/setup-zig@v2
        with:
          version: 0.11.0

      - name: Fetch dependencies
        run: mix deps.get

      - name: Cross-compile
        run: mix compile
        env:
          DESKTOPUI_PREFER_COMPILER: zig
          DESKTOPUI_TARGET: ${{ matrix.target }}

      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: nif-${{ matrix.target }}
          path: priv/desktop_ui_nif.so
```

### Release Build with Artifacts

Create releases with pre-built binaries:

```yaml
name: Release

on:
  push:
    tags:
      - "v*"

jobs:
  release:
    name: Build release for ${{ matrix.target }}
    runs-on: ubuntu-latest
    strategy:
      matrix:
        target:
          - x86_64-linux-gnu
          - x86_64-linux-musl
          - aarch64-linux-gnu
          - x86_64-macos-none
          - aarch64-macos-none
          - x86_64-windows-gnu

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Install Erlang/Elixir
        uses: erlef/setup-beam@v1
        with:
          otp-version: "27"
          elixir-version: "1.18"

      - name: Install build dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y build-essential libsdl2-dev

      - name: Install Zig
        uses: goto-bus-stop/setup-zig@v2
        with:
          version: 0.11.0

      - name: Fetch dependencies
        run: mix deps.get

      - name: Build release
        run: |
          MIX_ENV=prod mix compile
          mix release
        env:
          DESKTOPUI_PREFER_COMPILER: zig
          DESKTOPUI_TARGET: ${{ matrix.target }}

      - name: Package release
        run: |
          tar czf desktopui-${{ matrix.target }}.tar.gz \
            -C _build/prod/rel/desktopui .

      - name: Upload to release
        uses: softprops/action-gh-release@v1
        with:
          files: desktopui-${{ matrix.target }}.tar.gz
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## GitLab CI

### Basic Pipeline

```yaml
stages:
  - build
  - test

build:
  stage: build
  script:
    - apt-get update && apt-get install -y build-essential libsdl2-dev
    - mix deps.get
    - mix compile
  artifacts:
    paths:
      - priv/desktop_ui_nif.so
      - _build/

test:
  stage: test
  dependencies:
    - build
  script:
    - mix test
```

### Cross-Compilation

```yaml
stages:
  - build

build:linux:
  stage: build
  image: ghcr.io/ziglang/zig:ubuntu-*ls
  script:
    - mix deps.get
    - DESKTOPUI_PREFER_COMPILER=zig DESKTOPUI_TARGET=x86_64-linux-gnu mix compile
  artifacts:
    paths:
      - priv/desktop_ui_nif.so

build:macos:
  stage: build
  tags:
    - macos
  script:
    - brew install sdl2 zig
    - mix deps.get
    - DESKTOPUI_PREFER_COMPILER=zig DESKTOPUI_TARGET=aarch64-macos-none mix compile
  artifacts:
    paths:
      - priv/desktop_ui_nif.so
```

## Docker

### Dockerfile for Building

```dockerfile
FROM ghcr.io/ziglang/zig:ubuntu-latest AS builder

# Install Erlang/Elixir
RUN apt-get update && apt-get install -y \
    curl \
    build-essential \
    libsdl2-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Erlang
RUN curl -O https://packages.erlang-solutions.com/ubuntu/erlang_solutions.asc && \
    apt-key add erlang_solutions.asc && \
    echo "deb https://packages.erlang-solutions.com/ubuntu focal contrib" >> /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y esl-erlang elixir

WORKDIR /app

# Copy and build
COPY mix.exs mix.lock ./
RUN mix deps.get

COPY . .
RUN mix compile

# Runtime image
FROM ubuntu:22.04
RUN apt-get update && apt-get install -y \
    libSDL2-2.0-0 \
    erlang \
    elixir \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /app/_build ./_build
COPY --from=builder /app/priv ./priv
COPY --from=builder /app/lib ./lib
COPY --from=builder /app/mix.exs ./

CMD ["iex", "-S", "mix"]
```

### Multi-Platform Docker Build

```bash
# Build for multiple platforms
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --tag desktopui:latest \
  --output type=registry,ref=desktopui:latest \
  .
```

## Build Scripts

### Unix Build Script

```bash
#!/usr/bin/env bash
set -e

echo "Building DesktopUI..."

# Detect platform
OS=$(uname -s)
ARCH=$(uname -m)

case "$OS" in
  Linux)
    TARGET="${ARCH}-linux-gnu"
    ;;
  Darwin)
    TARGET="${ARCH}-macos-none"
    ;;
  *)
    echo "Unknown OS: $OS"
    exit 1
    ;;
esac

echo "Target: $TARGET"

# Check for Zig
if command -v zig &> /dev/null; then
  export DESKTOPUI_PREFER_COMPILER=zig
  echo "Using Zig compiler"
fi

# Set target
export DESKTOPUI_TARGET="$TARGET"

# Build
mix deps.get
mix compile

echo "Build complete: priv/desktop_ui_nif.so"
```

### Cross-Compile Script

```bash
#!/usr/bin/env bash
set -e

TARGETS=(
  "x86_64-linux-gnu"
  "x86_64-linux-musl"
  "aarch64-linux-gnu"
  "x86_64-macos-none"
  "aarch64-macos-none"
  "x86_64-windows-gnu"
)

for target in "${TARGETS[@]}"; do
  echo "Building for $target..."
  DESKTOPUI_PREFER_COMPILER=zig \
  DESKTOPUI_TARGET="$target" \
  mix compile

  # Copy artifact
  cp priv/desktop_ui_nif.so "priv/desktop_ui_nif.$target.so"

  echo "Built: priv/desktop_ui_nif.$target.so"
done

echo "All builds complete!"
```

## Nix

### shell.nix for Development

```nix
{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    # Erlang/Elixir
    erlang
    elixir

    # Build tools
    zig
    gcc
    pkg-config

    # SDL2
    SDL2

    # Utilities
    ccache
  ];

  shellHook = ''
    export DESKTOPUI_PREFER_COMPILER=zig
    echo "DesktopUI development environment ready!"
    echo "Elixir: $(elixir --version | head -1)"
    echo "Zig: $(zig version)"
  '';
}
```

### flake.nix

```nix
{
  description = "DesktopUI development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            erlang elixir zig SDL2 pkg-config
          ];
        };
      });
}
```

## CircleCI

```yaml
version: 2.1

orbs:
  elixir: circleci/elixir@2.0.0

jobs:
  build:
    docker:
      - image: cimg/elixir:1.18.0
    steps:
      - checkout
      - run:
          name: Install dependencies
          command: |
            sudo apt-get update
            sudo apt-get install -y build-essential libsdl2-dev
      - elixir/install-deps
      - run:
          name: Compile
          command: mix compile
          environment:
            DESKTOPUI_PREFER_COMPILER: zig
      - run:
          name: Test
          command: mix test
```

## Pre-commit Hook

```bash
#!/usr/bin/env bash
# .git/hooks/pre-commit

# Format code
mix format

# Run tests
mix test --stale

# Check if NIF needs rebuild
if [ "_build/dev/lib/desktop_ui/.compile.desktop_ui_nif" -ot "c_src/*.c" ]; then
  echo "NIF sources changed, rebuilding..."
  mix compile
fi
```

## Tips and Best Practices

### Caching Dependencies

```yaml
- name: Cache Mix dependencies
  uses: actions/cache@v3
  with:
    path: |
      deps
      _build
    key: ${{ runner.os }}-mix-${{ hashFiles('**/mix.lock') }}
    restore-keys: |
      ${{ runner.os }}-mix-
```

### Parallel Testing

```yaml
- name: Test
  run: mix test --max-cases=$(nproc)
```

### Build Matrix Optimization

Skip redundant builds (e.g., macOS on macOS runner):

```yaml
include:
  - os: ubuntu-latest
    target: x86_64-linux-gnu
    cross_compile: true
  - os: macos-latest
    target: aarch64-macos-none
    cross_compile: false  # Native build
```

### Artifact Naming

Use consistent naming for artifacts:

```bash
desktopui-${VERSION}-${TARGET}.${EXT}
# Examples:
# desktopui-1.0.0-x86_64-linux-gnu.tar.gz
# desktopui-1.0.0-aarch64-macos-none.tar.gz
# desktopui-1.0.0-x86_64-windows-gnu.zip
```

## See Also

- [Getting Started Guide](getting-started.md)
- [Cross-Compilation Guide](cross-compilation.md)
- [Compiler Reference](compiler-reference.md)

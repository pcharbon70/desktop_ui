#!/usr/bin/env bash
# DesktopUI Release Builder for Unix (Linux/macOS)
#
# Builds distributable releases with bundled SDL2 dependencies

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

APP_NAME="desktop_ui"
RELEASE_DIR="release"
DIST_DIR="releases"

# Detect platform
if [[ "$OSTYPE" == "darwin"* ]]; then
    PLATFORM="macos"
    SDL2_PATH="${SDL2_PATH:-$(brew --prefix sdl2 2>/dev/null || echo /usr/local)}"
    LIB_EXT="dylib"
else
    PLATFORM="linux"
    SDL2_PATH="${SDL2_PATH:-/usr/local}"
    LIB_EXT="so.0"
fi

# Detect architecture
ARCH=$(uname -m)

# ============================================================================
# Helper Functions
# ============================================================================

log_info() {
    echo -e "\033[36m$*\033[0m"
}

log_success() {
    echo -e "\033[32m✓ $*\033[0m"
}

log_warn() {
    echo -e "\033[33m⚠ $*\033[0m"
}

log_error() {
    echo -e "\033[31m✗ $*\033[0m"
}

get_app_version() {
    grep -oP 'version:\s*"\K[^"]+' mix.exs 2>/dev/null || echo "0.1.0"
}

# ============================================================================
# Main Script
# ============================================================================

echo "=== DesktopUI Release Builder for $PLATFORM ==="
echo ""

# Check SDL2
if [[ ! -d "$SDL2_PATH" ]]; then
    log_error "SDL2 not found at: $SDL2_PATH"
    log_warn "Please install SDL2:"
    if [[ "$PLATFORM" == "macos" ]]; then
        log_warn "  brew install sdl2"
    else
        log_warn "  sudo apt-get install libsdl2-dev"
    fi
    exit 1
fi

log_success "SDL2 found at: $SDL2_PATH"
echo ""

# Get version
VERSION=$(get_app_version)
log_success "Version: $VERSION"
echo ""

log_info "Platform: $PLATFORM $ARCH"
echo ""

# Clean previous release
log_info "Cleaning previous release..."
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"/{bin,priv,lib}

# Build NIF
log_info "Building NIF..."
if ! mix compile.desktop_ui_nif; then
    log_error "NIF compilation failed"
    exit 1
fi
log_success "NIF compiled"
echo ""

# Copy NIF
log_info "Copying NIF..."
NIF_SOURCE="_build/dev/lib/desktop_ui/priv/desktop_ui_nif.$LIB_EXT"
if [[ ! -f "$NIF_SOURCE" ]]; then
    log_error "NIF not found at: $NIF_SOURCE"
    exit 1
fi
cp "$NIF_SOURCE" "$RELEASE_DIR/priv/"
log_success "NIF copied"
echo ""

# Copy SDL2
log_info "Copying SDL2..."
SDL2_LIB="$SDL2_PATH/lib/libSDL2-2.0.$LIB_EXT"
if [[ ! -f "$SDL2_LIB" ]]; then
    log_error "SDL2 library not found at: $SDL2_LIB"
    exit 1
fi
cp "$SDL2_LIB" "$RELEASE_DIR/lib/"

# macOS: Update install name to use @rpath
if [[ "$PLATFORM" == "macos" ]]; then
    install_name_tool -id @rpath/libSDL2-2.0.dylib "$RELEASE_DIR/lib/libSDL2-2.0.dylib"
fi

log_success "SDL2 copied"
echo ""

# Create launcher script
log_info "Creating launcher script..."
cat > "$RELEASE_DIR/bin/$APP_NAME" <<EOF
#!/bin/bash
# DesktopUI $APP_NAME Launcher

SCRIPT_DIR="\$(cd "\$(dirname "\$0")" && pwd)"

# Set library path
if [[ "\$OSTYPE" == "darwin"* ]]; then
    export DYLD_LIBRARY_PATH="\$SCRIPT_DIR/../lib:\$DYLD_LIBRARY_PATH"
else
    export LD_LIBRARY_PATH="\$SCRIPT_DIR/../lib:\$LD_LIBRARY_PATH"
fi

cd "\$SCRIPT_DIR/.."

echo "Starting DesktopUI $APP_NAME..."
exec mix run run_counter.exs
EOF

chmod +x "$RELEASE_DIR/bin/$APP_NAME"
log_success "Launcher created"
echo ""

# Create README
log_info "Creating README..."
cat > "$RELEASE_DIR/README.md" <<EOF
# DesktopUI $APP_NAME v$VERSION

## Quick Start

\`\`\`bash
./bin/$APP_NAME
\`\`\`

## Directory Structure

\`\`\`
$APP_NAME/
├── bin/
│   └── $APP_NAME         # Launcher script
├── priv/
│   └── desktop_ui_nif.$LIB_EXT  # NIF library
├── lib/
│   └── libSDL2-2.0.$LIB_EXT    # SDL2 library
└── run_counter.exs         # Application script
\`\`\`

## Requirements

- ${PLATFORM^} ${ARCH}
- Elixir 1.18+ (for running from source)
- SDL2 libraries (included)

## Troubleshooting

If you see "library not loaded" or "cannot open shared object file":

1. Make sure you're using the launcher script
2. Verify the library exists in the \`lib/\` directory
3. Check file permissions: \`chmod +x bin/$APP_NAME\`

## Credits

This application uses SDL2 (Simple DirectMedia Layer)
Copyright (C) 1997-2024 Sam Lantinga <slouken@libsdl.org>
https://www.libsdl.org/
EOF

log_success "README created"
echo ""

# Create distribution package
log_info "Creating distribution package..."
mkdir -p "$DIST_DIR"
ARCHIVE_FILE="$DIST_DIR/${APP_NAME}_v${VERSION}_${PLATFORM}-${ARCH}.tar.gz"

tar czf "$ARCHIVE_FILE" -C "$RELEASE_DIR" .

log_success "Package created: $ARCHIVE_FILE"
echo ""

# Summary
echo "=== Release Complete ==="
echo ""
log_success "Release created successfully!"
echo ""
echo -e "Location: \033[36m$RELEASE_DIR\033[0m"
echo -e "Package:  \033[36m$ARCHIVE_FILE\033[0m"
echo ""
log_info "To test the release:"
echo "  1. Extract the archive:"
echo "     tar xzf $ARCHIVE_FILE"
echo "  2. Run the application:"
echo "     cd release && ./bin/$APP_NAME"
echo ""

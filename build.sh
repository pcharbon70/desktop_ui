#!/usr/bin/env bash
set -e

# DesktopUI Build Script
# Handles the chicken-and-egg bootstrapping issue with the NIF compiler.

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default compiler preference
DESKTOPUI_PREFER_COMPILER="${DESKTOPUI_PREFER_COMPILER:-makefile}"

echo -e "${CYAN}DesktopUI Build Script${NC}"
echo ""

# Detect if Zig is available
if command -v zig &> /dev/null; then
    ZIG_VERSION=$(zig version 2>/dev/null || echo "unknown")
    echo -e "${GREEN}✓${NC} Zig found: $ZIG_VERSION"

    # Check if Zig version works (not 0.15.2 CacheCheckFailed issue)
    if [[ "$ZIG_VERSION" == "0.15.2"* ]]; then
        echo -e "${YELLOW}!${NC} Zig 0.15.2 has CacheCheckFailed issues, using Makefile"
        DESKTOPUI_PREFER_COMPILER="makefile"
    else
        DESKTOPUI_PREFER_COMPILER="zig"
    fi
else
    echo -e "${YELLOW}!${NC} Zig not found, will use Makefile"
    DESKTOPUI_PREFER_COMPILER="makefile"
fi

# Detect if make is available
if command -v make &> /dev/null; then
    echo -e "${GREEN}✓${NC} Make found"
else
    echo -e "${RED}✗${NC} Make not found. Please install either Zig or Make."
    exit 1
fi

echo ""
echo "Step 1: Compiling Elixir code (bootstrapping)..."

# Step 1: Compile Elixir code without NIF
DESKTOPUI_SKIP_NIF=1 mix compile

if [ $? -ne 0 ]; then
    echo -e "${RED}✗${NC} Elixir compilation failed"
    exit 1
fi

echo -e "${GREEN}✓${NC} Elixir code compiled"
echo ""

echo "Step 2: Compiling NIF with $DESKTOPUI_PREFER_COMPILER..."

# Step 2: Compile the NIF
DESKTOPUI_PREFER_COMPILER="$DESKTOPUI_PREFER_COMPILER" mix compile.desktop_ui_nif

if [ $? -ne 0 ]; then
    echo -e "${RED}✗${NC} NIF compilation failed"
    exit 1
fi

echo -e "${GREEN}✓${NC} NIF compiled"
echo ""

# Verify NIF exists
NIF_FILE="priv/desktop_ui_nif.so"
if [ -f "$NIF_FILE" ]; then
    SIZE=$(du -h "$NIF_FILE" | cut -f1)
    echo -e "${GREEN}✓${NC} NIF created: $NIF_FILE ($SIZE)"
else
    echo -e "${YELLOW}!${NC} Warning: NIF file not found at $NIF_FILE"
fi

echo ""
echo -e "${GREEN}=== Build Complete ===${NC}"
echo ""
echo "You can now run:"
echo "  mix test           # Run tests"
echo "  mix run            # Start IEx"
echo "  elixir run.exs     # Run the application"

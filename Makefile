# DesktopUI Makefile for NIF Compilation
#
# This Makefile compiles the C NIF code into a shared library that BEAM can load.
# It handles platform detection and SDL2 dependency checking.

# ============================================================================
# Configuration
# ============================================================================

# Project name
PROJECT = desktop_ui

# NIF library name (will be libdesktop_ui_nif.so on Linux, .dylib on macOS)
NIF_NAME = desktop_ui_nif

# Source files
C_SRC = $(wildcard c_src/*.c)
C_HEADERS = $(wildcard c_src/*.h)

# Build directory
BUILD_DIR = priv

# Output file
priv/$(NIF_NAME).so: $(C_SRC) | priv
	$(CC) -o $@ -shared -fPIC $(C_SRC) -I$(ERTS_INCLUDE_DIR) $(LDFLAGS) $(CFLAGS)

# Create priv directory if it doesn't exist
priv:
	mkdir -p priv

# ============================================================================
# Platform Detection
# ============================================================================

UNAME_S := $(shell uname -s)

# Erlang Runtime System (ERTS) include directory
# This is needed to compile NIFs
ERTS_INCLUDE_DIR = $(shell erl -noshell -s init stop -eval "io:format(\"~s/erts-~s/include\", [code:root_dir(), erlang:system_info(version)]).")

# Platform-specific settings
ifeq ($(UNAME_S),Linux)
    # Linux settings
    NIF_EXT = .so
    LDFLAGS = -shared -fPIC
    CFLAGS = -O2 -Wall -Wextra -Werror
    SDL2_CONFIG = sdl2-config
    SDL2_CFLAGS = $(shell $(SDL2_CONFIG) --cflags 2>/dev/null || echo "")
    SDL2_LDFLAGS = $(shell $(SDL2_CONFIG) --libs 2>/dev/null || echo "")
    ifeq ($(SDL2_CFLAGS),)
        $(warning SDL2 development libraries not found. Install with: sudo apt-get install libsdl2-dev)
    endif
else ifeq ($(UNAME_S),Darwin)
    # macOS settings
    NIF_EXT = .dylib
    LDFLAGS = -dynamiclib -undefined dynamic_lookup
    CFLAGS = -O2 -Wall -Wextra
    SDL2_CONFIG = sdl2-config
    SDL2_CFLAGS = $(shell $(SDL2_CONFIG) --cflags 2>/dev/null || echo "")
    SDL2_LDFLAGS = $(shell $(SDL2_CONFIG) --libs 2>/dev/null || echo "")
    ifeq ($(SDL2_CFLAGS),)
        $(warning SDL2 development libraries not found. Install with: brew install sdl2)
    endif
else
    $(error Unsupported platform: $(UNAME_S). Please use Linux or macOS.)
endif

# Combine flags
ALL_CFLAGS = $(CFLAGS) $(SDL2_CFLAGS) -I$(ERTS_INCLUDE_DIR)
ALL_LDFLAGS = $(LDFLAGS) $(SDL2_LDFLAGS)

# ============================================================================
# Build Targets
# ============================================================================

.PHONY: all clean check-sdl2 help

# Default target
all: priv/$(NIF_NAME)$(NIF_EXT)

# Compile the NIF shared library
priv/$(NIF_NAME)$(NIF_EXT): $(C_SRC) | priv
	@echo "Compiling NIF: $(NIF_NAME)$(NIF_EXT)"
	@echo "ERTS Include: $(ERTS_INCLUDE_DIR)"
	@echo "CFLAGS: $(ALL_CFLAGS)"
	@echo "LDFLAGS: $(ALL_LDFLAGS)"
	$(CC) -o $@ -shared -fPIC $(C_SRC) -I$(ERTS_INCLUDE_DIR) $(ALL_CFLAGS) $(ALL_LDFLAGS)
	@echo "NIF compiled successfully: $@"

# Check if SDL2 is available
check-sdl2:
	@echo "Checking for SDL2..."
	@which $(SDL2_CONFIG) > /dev/null 2>&1 || \
	    (echo "SDL2 not found. Please install SDL2 development libraries:" && \
	     echo "  Ubuntu/Debian: sudo apt-get install libsdl2-dev" && \
	     echo "  macOS: brew install sdl2" && \
	     exit 1)
	@echo "SDL2 found: $(SDL2_CONFIG)"
	@echo "SDL2 CFLAGS: $(SDL2_CFLAGS)"
	@echo "SDL2 LDFLAGS: $(SDL2_LDFLAGS)"

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -f priv/$(NIF_NAME).so priv/$(NIF_NAME).dylib
	rm -rf priv/*.o
	@echo "Clean complete."

# Help target
help:
	@echo "DesktopUI NIF Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  all (default)  - Compile the NIF shared library"
	@echo "  clean          - Remove build artifacts"
	@echo "  check-sdl2     - Check if SDL2 is installed"
	@echo "  help           - Show this help message"
	@echo ""
	@echo "Platform: $(UNAME_S)"
	@echo "NIF Extension: $(NIF_EXT)"
	@echo "ERTS Include: $(ERTS_INCLUDE_DIR)"

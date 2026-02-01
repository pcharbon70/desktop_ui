# DesktopUI Makefile for NIF Compilation
#
# This Makefile compiles the C NIF code into a shared library that BEAM can load.
# It handles platform detection and SDL2 dependency checking.
#
# This Makefile can be used standalone or invoked by the Mix compiler.
# When invoked by Mix, environment variables are passed for configuration.

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

# ============================================================================
# Environment Variable Overrides (for Mix compiler integration)
# ============================================================================

# DESKTOPUI_TARGET: Target triple for cross-compilation (e.g., x86_64-windows-gnu)
# If set, override platform detection
ifdef DESKTOPUI_TARGET
    TARGET_OVERRIDE = $(DESKTOPUI_TARGET)
else
    TARGET_OVERRIDE =
endif

# ERTS_INCLUDE_DIR: Override ERTS include directory detection
# If set by Mix compiler, use it instead of running erl command
ifdef ERTS_INCLUDE_DIR
    ERTS_INCLUDE = $(ERTS_INCLUDE_DIR)
else
    ERTS_INCLUDE = $(shell erl -noshell -s init stop -eval "io:format(\"~s/erts-~s/include\", [code:root_dir(), erlang:system_info(version)]).")
endif

# SDL2_CFLAGS: Override SDL2 cflags detection
# If set by Mix compiler, use it instead of running sdl2-config
ifdef SDL2_CFLAGS
    SDL2_CFLAGS_OVERRIDE = $(SDL2_CFLAGS)
else
    SDL2_CFLAGS_OVERRIDE =
endif

# SDL2_LDFLAGS: Override SDL2 ldflags detection
# If set by Mix compiler, use it instead of running sdl2-config
ifdef SDL2_LDFLAGS
    SDL2_LDFLAGS_OVERRIDE = $(SDL2_LDFLAGS)
else
    SDL2_LDFLAGS_OVERRIDE =
endif

# ============================================================================
# Platform Detection
# ============================================================================

UNAME_S := $(shell uname -s)

# Check if we have a target override
ifneq ($(TARGET_OVERRIDE),)
    # Parse target triple for platform-specific settings
    ifneq ($(findstring windows,$(TARGET_OVERRIDE)),)
        # Windows target
        NIF_EXT = .dll
        LDFLAGS = -shared -fPIC
        CFLAGS = -O2 -Wall -Wextra
        # For Windows cross-compilation, assume SDL2 flags are provided
    else ifneq ($(findstring linux,$(TARGET_OVERRIDE)),)
        # Linux target
        NIF_EXT = .so
        LDFLAGS = -shared -fPIC
        CFLAGS = -O2 -Wall -Wextra
    else ifneq ($(findstring macos,$(TARGET_OVERRIDE)),)
        # macOS target
        NIF_EXT = .dylib
        LDFLAGS = -dynamiclib -undefined dynamic_lookup
        CFLAGS = -O2 -Wall -Wextra
    else
        $(error Unknown target: $(TARGET_OVERRIDE))
    endif
else
    # No target override, detect from host system
    ifeq ($(UNAME_S),Linux)
        # Linux settings
        NIF_EXT = .so
        LDFLAGS = -shared -fPIC
        CFLAGS = -O2 -Wall -Wextra -Werror
        SDL2_CONFIG = sdl2-config
        ifeq ($(SDL2_CFLAGS_OVERRIDE),)
            SDL2_CFLAGS = $(shell $(SDL2_CONFIG) --cflags 2>/dev/null || echo "")
        else
            SDL2_CFLAGS = $(SDL2_CFLAGS_OVERRIDE)
        endif
        ifeq ($(SDL2_LDFLAGS_OVERRIDE),)
            SDL2_LDFLAGS = $(shell $(SDL2_CONFIG) --libs 2>/dev/null || echo "")
        else
            SDL2_LDFLAGS = $(SDL2_LDFLAGS_OVERRIDE)
        endif
        ifeq ($(SDL2_CFLAGS),)
            $(warning SDL2 development libraries not found. Install with: sudo apt-get install libsdl2-dev)
        endif
    else ifeq ($(UNAME_S),Darwin)
        # macOS settings
        NIF_EXT = .dylib
        LDFLAGS = -dynamiclib -undefined dynamic_lookup
        CFLAGS = -O2 -Wall -Wextra
        SDL2_CONFIG = sdl2-config
        ifeq ($(SDL2_CFLAGS_OVERRIDE),)
            SDL2_CFLAGS = $(shell $(SDL2_CONFIG) --cflags 2>/dev/null || echo "")
        else
            SDL2_CFLAGS = $(SDL2_CFLAGS_OVERRIDE)
        endif
        ifeq ($(SDL2_LDFLAGS_OVERRIDE),)
            SDL2_LDFLAGS = $(shell $(SDL2_CONFIG) --libs 2>/dev/null || echo "")
        else
            SDL2_LDFLAGS = $(SDL2_LDFLAGS_OVERRIDE)
        endif
        ifeq ($(SDL2_CFLAGS),)
            $(warning SDL2 development libraries not found. Install with: brew install sdl2)
        endif
    else
        $(error Unsupported platform: $(UNAME_S). Please use Linux or macOS.)
    endif
endif

# Use ERTS_INCLUDE from either override or detection
ERTS_INCLUDE_DIR := $(ERTS_INCLUDE)

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

# Create priv directory if it doesn't exist
priv:
	mkdir -p priv

# Check if SDL2 is available
check-sdl2:
	@echo "Checking for SDL2..."
ifndef SDL2_CONFIG
	@echo "SDL2_CONFIG not set, skipping check (may be cross-compiling)"
else
	@which $(SDL2_CONFIG) > /dev/null 2>&1 || \
	    (echo "SDL2 not found. Please install SDL2 development libraries:" && \
	     echo "  Ubuntu/Debian: sudo apt-get install libsdl2-dev" && \
	     echo "  macOS: brew install sdl2" && \
	     exit 1)
	@echo "SDL2 found: $(SDL2_CONFIG)"
	@echo "SDL2 CFLAGS: $(SDL2_CFLAGS)"
	@echo "SDL2 LDFLAGS: $(SDL2_LDFLAGS)"
endif

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -f priv/$(NIF_NAME).so priv/$(NIF_NAME).dylib priv/$(NIF_NAME).dll
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
	@echo "Environment Variables:"
	@echo "  DESKTOPUI_TARGET    - Target triple for cross-compilation"
	@echo "  ERTS_INCLUDE_DIR    - Override ERTS include directory"
	@echo "  SDL2_CFLAGS         - Override SDL2 C compiler flags"
	@echo "  SDL2_LDFLAGS        - Override SDL2 linker flags"
	@echo ""
	@echo "Platform: $(UNAME_S)"
	@echo "Target: $(TARGET_OVERRIDE)"
	@echo "NIF Extension: $(NIF_EXT)"
	@echo "ERTS Include: $(ERTS_INCLUDE_DIR)"

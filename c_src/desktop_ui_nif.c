/*
 * DesktopUI NIF - Native Implemented Functions for DesktopUI
 *
 * This module provides the native interface to SDL2 for the DesktopUI framework.
 * It wraps SDL2 functions and makes them callable from Elixir.
 *
 * Architecture:
 *   Elixir (DesktopUI.Graphics) -> NIF (this file) -> SDL2 Library
 *
 * NIF Safety:
 *   - All NIF functions must be crash-safe
 *   - Validate all input parameters
 *   - Use enif_protect/enif_unprotect for long-running operations
 *   - Never block in NIF (use async threads for long operations)
 *
 * For more information on Erlang NIFs:
 *   http://erlang.org/doc/man/erl_nif.html
 */

#include <erl_nif.h>
#include <string.h>
#include <stdio.h>
#include <stdint.h>

/*
 * Try to include SDL2 headers - if not available, we'll provide stub implementations
 * This allows the NIF to compile even without SDL2, with graceful fallback
 */
#if defined(DESKTOPUI_HAS_SDL2)
  /* Already defined via compiler flag */
#elif defined(__has_include)
  #if __has_include(<SDL2/SDL.h>)
    #define DESKTOPUI_HAS_SDL2 1
    #include <SDL2/SDL.h>
  #else
    #define DESKTOPUI_HAS_SDL2 0
  #endif
#else
  /* Try to include anyway - will fail at compile time if not available */
  #define DESKTOPUI_HAS_SDL2 1
  #include <SDL2/SDL.h>
#endif

/*
 * Forward declarations for SDL types when SDL2 is not available
 */
#if !DESKTOPUI_HAS_SDL2
typedef struct SDL_Window SDL_Window;
typedef struct SDL_Renderer SDL_Renderer;
struct SDL_Window {
    int dummy;
};
struct SDL_Renderer {
    int dummy;
};

/* Stub SDL functions for when SDL2 is not available */
#define SDL_INIT_VIDEO 0x00000020
#define SDL_RENDERER_ACCELERATED 0x00000002
#define SDL_RENDERER_PRESENTVSYNC 0x00000004
static inline int SDL_Init(uint32_t flags) {
    (void)flags;
    return -1;
}
static inline void SDL_Quit(void) {}
static inline const char* SDL_GetError(void) {
    return "SDL2 not available at compile time";
}
static inline SDL_Window* SDL_CreateWindow(const char* title, int x, int y, int w, int h, uint32_t flags) {
    (void)title; (void)x; (void)y; (void)w; (void)h; (void)flags;
    return NULL;
}
static inline void SDL_DestroyWindow(SDL_Window* window) {
    (void)window;
}
static inline uint32_t SDL_GetWindowID(SDL_Window* window) {
    (void)window;
    return 0;
}
static inline void SDL_GetWindowSize(SDL_Window* window, int* w, int* h) {
    (void)window;
    if (w) *w = 0;
    if (h) *h = 0;
}
static inline void SDL_SetWindowSize(SDL_Window* window, int w, int h) {
    (void)window; (void)w; (void)h;
}
static inline void SDL_SetWindowTitle(SDL_Window* window, const char* title) {
    (void)window; (void)title;
}

/* Renderer stubs */
static inline SDL_Renderer* SDL_CreateRenderer(SDL_Window* window, int index, uint32_t flags) {
    (void)window; (void)index; (void)flags;
    return NULL;
}
static inline void SDL_DestroyRenderer(SDL_Renderer* renderer) {
    (void)renderer;
}
static inline int SDL_SetRenderDrawColor(SDL_Renderer* renderer, Uint8 r, Uint8 g, Uint8 b, Uint8 a) {
    (void)renderer; (void)r; (void)g; (void)b; (void)a;
    return -1;
}
static inline int SDL_RenderClear(SDL_Renderer* renderer) {
    (void)renderer;
    return -1;
}
static inline int SDL_RenderDrawRect(SDL_Renderer* renderer, const SDL_Rect* rect) {
    (void)renderer; (void)rect;
    return -1;
}
static inline int SDL_RenderFillRect(SDL_Renderer* renderer, const SDL_Rect* rect) {
    (void)renderer; (void)rect;
    return -1;
}
static inline void SDL_RenderPresent(SDL_Renderer* renderer) {
    (void)renderer;
}
typedef struct {
    Uint8 b, g, r, a;
} SDL_Color;
typedef struct {
    int x, y, w, h;
} SDL_Rect;
#endif

/*
 * ============================================================================
 * NIF State Management
 * ============================================================================
 */

/* Maximum number of windows we can track */
#define MAX_WINDOWS 128

/* Maximum number of renderers we can track */
#define MAX_RENDERERS 128

/* Window resource structure - tracks an SDL_Window */
typedef struct {
    SDL_Window* window;
    uint32_t window_id;
    int width;
    int height;
    int in_use;
} window_resource_t;

/* Renderer resource structure - tracks an SDL_Renderer */
typedef struct {
    SDL_Renderer* renderer;
    int window_id;              /* Associated window ID */
    int renderer_id;             /* Our tracking ID */
    SDL_Color draw_color;       /* Current draw color */
    int in_use;
} renderer_resource_t;

typedef struct {
    int initialized;
    int sdl_initialized;       /* Whether SDL_Init was called */
    char last_error[512];
    char version[32];
    window_resource_t windows[MAX_WINDOWS];
    int window_count;
    renderer_resource_t renderers[MAX_RENDERERS];
    int renderer_count;
} desktop_ui_nif_state;

/*
 * ============================================================================
 * NIF Function Declarations
 * ============================================================================
 */

static ERL_NIF_TERM nif_initialize(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
static ERL_NIF_TERM nif_get_version(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
static ERL_NIF_TERM nif_get_error(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
static ERL_NIF_TERM nif_is_initialized(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);

/* Window management functions */
static ERL_NIF_TERM nif_sdl_init(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
static ERL_NIF_TERM nif_create_window(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
static ERL_NIF_TERM nif_destroy_window(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
static ERL_NIF_TERM nif_get_window_size(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
static ERL_NIF_TERM nif_set_window_size(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
static ERL_NIF_TERM nif_set_window_title(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);

/* Renderer and drawing functions */
static ERL_NIF_TERM nif_create_renderer(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
static ERL_NIF_TERM nif_destroy_renderer(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
static ERL_NIF_TERM nif_set_render_draw_color(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
static ERL_NIF_TERM nif_clear_render(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
static ERL_NIF_TERM nif_draw_rect(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
static ERL_NIF_TERM nif_fill_rect(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
static ERL_NIF_TERM nif_present_render(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);

/* Helper functions */
static void set_last_error(desktop_ui_nif_state* state, const char* error);
static int find_window_slot(desktop_ui_nif_state* state);
static window_resource_t* find_window_by_id(desktop_ui_nif_state* state, int window_id);
static int find_renderer_slot(desktop_ui_nif_state* state);
static renderer_resource_t* find_renderer_by_id(desktop_ui_nif_state* state, int renderer_id);

/*
 * ============================================================================
 * NIF Load/Unload Callbacks
 * ============================================================================
 */

/*
 * Load callback - called when the NIF library is loaded
 *
 * This is called once when the NIF is first loaded. We use it to:
 * 1. Initialize our private state
 * 2. Store state for later use
 * 3. Return success/failure
 */
static int load(ErlNifEnv* env, void** priv_data, ERL_NIF_TERM load_info)
{
    (void)env;        // Suppress unused parameter warning
    (void)load_info;  // Suppress unused parameter warning

    desktop_ui_nif_state* state = (desktop_ui_nif_state*) enif_alloc(sizeof(desktop_ui_nif_state));
    if (!state) {
        return 1;  // Failure
    }

    // Initialize state
    state->initialized = 1;
    state->sdl_initialized = 0;  /* SDL2 not initialized yet */
    memset(state->last_error, 0, sizeof(state->last_error));
    strncpy(state->last_error, "No error", sizeof(state->last_error) - 1);
    memset(state->version, 0, sizeof(state->version));
    strncpy(state->version, "0.3.0-nif", sizeof(state->version) - 1);  /* Bump version for renderer support */

    // Initialize window tracking
    memset(state->windows, 0, sizeof(state->windows));
    state->window_count = 0;

    // Initialize renderer tracking
    memset(state->renderers, 0, sizeof(state->renderers));
    state->renderer_count = 0;

    // Store state in private data
    *priv_data = (void*) state;

    return 0;  // Success
}

/*
 * Reload callback - called when the NIF library is reloaded (code upgrade)
 */
static int reload(ErlNifEnv* env, void** priv_data, ERL_NIF_TERM load_info)
{
    (void)env;        // Suppress unused parameter warning
    (void)load_info;  // Suppress unused parameter warning

    // For now, just reload the state
    desktop_ui_nif_state* old_state = (desktop_ui_nif_state*) *priv_data;
    desktop_ui_nif_state* new_state = (desktop_ui_nif_state*) enif_alloc(sizeof(desktop_ui_nif_state));

    if (!new_state) {
        return 1;  // Failure
    }

    // Copy old state to new state
    if (old_state) {
        new_state->initialized = old_state->initialized;
        new_state->sdl_initialized = old_state->sdl_initialized;
        memcpy(new_state->last_error, old_state->last_error, sizeof(new_state->last_error));
        memcpy(new_state->version, old_state->version, sizeof(new_state->version));
        memcpy(new_state->windows, old_state->windows, sizeof(new_state->windows));
        new_state->window_count = old_state->window_count;
        memcpy(new_state->renderers, old_state->renderers, sizeof(new_state->renderers));
        new_state->renderer_count = old_state->renderer_count;
    } else {
        new_state->initialized = 1;
        new_state->sdl_initialized = 0;
        memset(new_state->last_error, 0, sizeof(new_state->last_error));
        strncpy(new_state->last_error, "No error", sizeof(new_state->last_error) - 1);
        memset(new_state->version, 0, sizeof(new_state->version));
        strncpy(new_state->version, "0.3.0-nif", sizeof(new_state->version) - 1);
        memset(new_state->windows, 0, sizeof(new_state->windows));
        new_state->window_count = 0;
        memset(new_state->renderers, 0, sizeof(new_state->renderers));
        new_state->renderer_count = 0;
    }

    *priv_data = (void*) new_state;
    return 0;  // Success
}

/*
 * Upgrade callback - called during code upgrade
 */
static int upgrade(ErlNifEnv* env, void** priv_data, void** old_priv_data, ERL_NIF_TERM load_info)
{
    (void)old_priv_data;  // Suppress unused parameter warning
    // Just reuse the reload logic for now
    return reload(env, priv_data, load_info);
}

/*
 * Unload callback - called when the NIF library is unloaded
 */
static void unload(ErlNifEnv* env, void* priv_data)
{
    (void)env;  // Suppress unused parameter warning
    desktop_ui_nif_state* state = (desktop_ui_nif_state*) priv_data;
    if (state) {
        // Clean up any remaining renderers first (before windows)
#if DESKTOPUI_HAS_SDL2
        for (int i = 0; i < MAX_RENDERERS; i++) {
            if (state->renderers[i].in_use && state->renderers[i].renderer) {
                SDL_DestroyRenderer(state->renderers[i].renderer);
                state->renderers[i].renderer = NULL;
                state->renderers[i].in_use = 0;
            }
        }
#endif

        // Clean up any remaining windows
#if DESKTOPUI_HAS_SDL2
        for (int i = 0; i < MAX_WINDOWS; i++) {
            if (state->windows[i].in_use && state->windows[i].window) {
                SDL_DestroyWindow(state->windows[i].window);
                state->windows[i].window = NULL;
                state->windows[i].in_use = 0;
            }
        }
#endif

        // Quit SDL if we initialized it
        if (state->sdl_initialized) {
#if DESKTOPUI_HAS_SDL2
            SDL_Quit();
#endif
            state->sdl_initialized = 0;
        }

        enif_free(state);
    }
}

/*
 * ============================================================================
 * NIF Implementations
 * ============================================================================
 */

/*
 * nif_initialize() -> {:ok, %{version: binary(), initialized: boolean()}}
 *
 * Initialize the NIF and return version information.
 * This is the first function that should be called after loading the NIF.
 */
static ERL_NIF_TERM nif_initialize(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
    (void)argv;  // Suppress unused parameter warning

    desktop_ui_nif_state* state = (desktop_ui_nif_state*) enif_priv_data(env);

    if (argc != 0) {
        return enif_make_badarg(env);
    }

    if (!state || !state->initialized) {
        // Return error tuple
        ERL_NIF_TERM error_msg = enif_make_string(env, "NIF not initialized", ERL_NIF_UTF8);
        return enif_make_tuple2(env, enif_make_atom(env, "error"), error_msg);
    }

    // Build success response with version info
    // Note: enif_make_string with ERL_NIF_UTF8 creates a binary in newer OTP versions
    ERL_NIF_TERM version = enif_make_string(env, state->version, ERL_NIF_UTF8);
    ERL_NIF_TERM initialized = enif_make_int(env, state->initialized);

    ERL_NIF_TERM map = enif_make_new_map(env);
    enif_make_map_put(env, map, enif_make_atom(env, "version"), version, &map);
    enif_make_map_put(env, map, enif_make_atom(env, "initialized"), initialized, &map);

    return enif_make_tuple2(env, enif_make_atom(env, "ok"), map);
}

/*
 * nif_get_version() -> binary()
 *
 * Get the NIF version string.
 */
static ERL_NIF_TERM nif_get_version(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
    (void)argc;   // Suppress unused parameter warning
    (void)argv;   // Suppress unused parameter warning

    desktop_ui_nif_state* state = (desktop_ui_nif_state*) enif_priv_data(env);

    if (!state) {
        return enif_make_string(env, "unknown", ERL_NIF_UTF8);
    }

    return enif_make_string(env, state->version, ERL_NIF_UTF8);
}

/*
 * nif_get_error() -> binary()
 *
 * Get the last error message from the NIF.
 */
static ERL_NIF_TERM nif_get_error(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
    (void)argc;   // Suppress unused parameter warning
    (void)argv;   // Suppress unused parameter warning

    desktop_ui_nif_state* state = (desktop_ui_nif_state*) enif_priv_data(env);

    if (!state) {
        return enif_make_string(env, "NIF state not available", ERL_NIF_UTF8);
    }

    return enif_make_string(env, state->last_error, ERL_NIF_UTF8);
}

/*
 * nif_is_initialized() -> boolean()
 *
 * Check if the NIF is properly initialized.
 */
static ERL_NIF_TERM nif_is_initialized(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
    (void)argc;   // Suppress unused parameter warning
    (void)argv;   // Suppress unused parameter warning

    desktop_ui_nif_state* state = (desktop_ui_nif_state*) enif_priv_data(env);

    if (!state || !state->initialized) {
        return enif_make_atom(env, "false");
    }

    return enif_make_atom(env, "true");
}

/*
 * ============================================================================
 * Window Management NIF Implementations
 * ============================================================================
 */

/*
 * Helper: Set the last error message in the state
 */
static void set_last_error(desktop_ui_nif_state* state, const char* error)
{
    if (state) {
        memset(state->last_error, 0, sizeof(state->last_error));
        strncpy(state->last_error, error, sizeof(state->last_error) - 1);
    }
}

/*
 * Helper: Find an available window slot
 * Returns slot index or -1 if full
 */
#if !DESKTOPUI_HAS_SDL2
__attribute__((unused))
#endif
static int find_window_slot(desktop_ui_nif_state* state)
{
    if (!state) {
        return -1;
    }

    for (int i = 0; i < MAX_WINDOWS; i++) {
        if (!state->windows[i].in_use) {
            return i;
        }
    }

    return -1;  // No available slots
}

/*
 * Helper: Find a window by its ID
 * Returns pointer to window resource or NULL
 */
#if !DESKTOPUI_HAS_SDL2
__attribute__((unused))
#endif
static window_resource_t* find_window_by_id(desktop_ui_nif_state* state, int window_id)
{
    if (!state || window_id < 0 || window_id >= MAX_WINDOWS) {
        return NULL;
    }

    window_resource_t* win = &state->windows[window_id];
    if (!win->in_use) {
        return NULL;
    }

    return win;
}

/*
 * Helper: Find an available renderer slot
 * Returns slot index or -1 if full
 */
#if !DESKTOPUI_HAS_SDL2
__attribute__((unused))
#endif
static int find_renderer_slot(desktop_ui_nif_state* state)
{
    if (!state) {
        return -1;
    }

    for (int i = 0; i < MAX_RENDERERS; i++) {
        if (!state->renderers[i].in_use) {
            return i;
        }
    }

    return -1;  // No available slots
}

/*
 * Helper: Find a renderer by its ID
 * Returns pointer to renderer resource or NULL
 */
#if !DESKTOPUI_HAS_SDL2
__attribute__((unused))
#endif
static renderer_resource_t* find_renderer_by_id(desktop_ui_nif_state* state, int renderer_id)
{
    if (!state || renderer_id < 0 || renderer_id >= MAX_RENDERERS) {
        return NULL;
    }

    renderer_resource_t* renderer = &state->renderers[renderer_id];
    if (!renderer->in_use) {
        return NULL;
    }

    return renderer;
}

/*
 * nif_sdl_init() -> {:ok, %{}} | {:error, reason}
 *
 * Initialize the SDL2 video subsystem.
 * This must be called before creating any windows.
 */
static ERL_NIF_TERM nif_sdl_init(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
    (void)argc;
    (void)argv;

    desktop_ui_nif_state* state = (desktop_ui_nif_state*) enif_priv_data(env);

    if (argc != 0) {
        return enif_make_badarg(env);
    }

    if (!state) {
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, "NIF state not available", ERL_NIF_UTF8));
    }

#if DESKTOPUI_HAS_SDL2
    // Initialize SDL video subsystem
    if (SDL_Init(SDL_INIT_VIDEO) < 0) {
        set_last_error(state, SDL_GetError());
        ERL_NIF_TERM error_msg = enif_make_string(env, SDL_GetError(), ERL_NIF_UTF8);
        return enif_make_tuple2(env, enif_make_atom(env, "error"), error_msg);
    }

    state->sdl_initialized = 1;
    set_last_error(state, "SDL2 initialized successfully");

    // Return success with empty map
    ERL_NIF_TERM map = enif_make_new_map(env);
    return enif_make_tuple2(env, enif_make_atom(env, "ok"), map);
#else
    set_last_error(state, "SDL2 not available at compile time");
    return enif_make_tuple2(env, enif_make_atom(env, "error"),
                            enif_make_string(env, "SDL2 not available at compile time", ERL_NIF_UTF8));
#endif
}

/*
 * nif_create_window(title, width, height, flags) -> {:ok, window_id} | {:error, reason}
 *
 * Create a new SDL2 window.
 *
 * Parameters:
 *   - title: Window title (binary)
 *   - width: Window width in pixels (integer)
 *   - height: Window height in pixels (integer)
 *   - flags: Window flags (integer, bitfield)
 *
 * Returns:
 *   - {:ok, window_id} on success
 *   - {:error, reason} on failure
 */
static ERL_NIF_TERM nif_create_window(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
    (void)argv;  // May be unused if SDL2 not available at compile time
    desktop_ui_nif_state* state = (desktop_ui_nif_state*) enif_priv_data(env);

    if (argc != 4) {
        return enif_make_badarg(env);
    }

    if (!state) {
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, "NIF state not available", ERL_NIF_UTF8));
    }

#if !DESKTOPUI_HAS_SDL2
    set_last_error(state, "SDL2 not available at compile time");
    return enif_make_tuple2(env, enif_make_atom(env, "error"),
                            enif_make_string(env, "SDL2 not available at compile time", ERL_NIF_UTF8));
#endif

#if DESKTOPUI_HAS_SDL2
    // Check if SDL is initialized
    if (!state->sdl_initialized) {
        set_last_error(state, "SDL2 not initialized. Call sdl_init/0 first.");
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, "SDL2 not initialized", ERL_NIF_UTF8));
    }

    // Extract title (binary)
    ErlNifBinary title_bin;
    if (!enif_inspect_binary(env, argv[0], &title_bin)) {
        return enif_make_badarg(env);
    }

    // Extract width (integer)
    int width;
    if (!enif_get_int(env, argv[1], &width)) {
        return enif_make_badarg(env);
    }

    // Extract height (integer)
    int height;
    if (!enif_get_int(env, argv[2], &height)) {
        return enif_make_badarg(env);
    }

    // Extract flags (integer)
    int flags;
    if (!enif_get_int(env, argv[3], &flags)) {
        return enif_make_badarg(env);
    }

    // Validate dimensions
    if (width <= 0 || height <= 0) {
        set_last_error(state, "Invalid window dimensions");
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, "Invalid window dimensions", ERL_NIF_UTF8));
    }

    // Find available window slot
    int slot = find_window_slot(state);
    if (slot < 0) {
        set_last_error(state, "Maximum number of windows reached");
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, "Maximum number of windows reached", ERL_NIF_UTF8));
    }

    // Create null-terminated title string
    char title_str[512];
    size_t copy_len = title_bin.size < sizeof(title_str) - 1 ? title_bin.size : sizeof(title_str) - 1;
    memcpy(title_str, title_bin.data, copy_len);
    title_str[copy_len] = '\0';

    // Create the window
    SDL_Window* window = SDL_CreateWindow(
        title_str,
        SDL_WINDOWPOS_UNDEFINED,
        SDL_WINDOWPOS_UNDEFINED,
        width,
        height,
        flags
    );

    if (!window) {
        set_last_error(state, SDL_GetError());
        ERL_NIF_TERM error_msg = enif_make_string(env, SDL_GetError(), ERL_NIF_UTF8);
        return enif_make_tuple2(env, enif_make_atom(env, "error"), error_msg);
    }

    // Store window in state
    state->windows[slot].window = window;
    state->windows[slot].window_id = SDL_GetWindowID(window);
    state->windows[slot].width = width;
    state->windows[slot].height = height;
    state->windows[slot].in_use = 1;
    state->window_count++;

    set_last_error(state, "Window created successfully");

    // Return success with window id (slot number for our tracking)
    ERL_NIF_TERM window_id_term = enif_make_int(env, slot);
    return enif_make_tuple2(env, enif_make_atom(env, "ok"), window_id_term);
#endif
}

/*
 * nif_destroy_window(window_id) -> :ok | {:error, reason}
 *
 * Destroy an SDL2 window and release its resources.
 *
 * Parameters:
 *   - window_id: Window ID (integer, returned from create_window)
 *
 * Returns:
 *   - :ok on success
 *   - {:error, reason} on failure
 */
static ERL_NIF_TERM nif_destroy_window(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
    (void)argv;  // May be unused if SDL2 not available at compile time
    desktop_ui_nif_state* state = (desktop_ui_nif_state*) enif_priv_data(env);

    if (argc != 1) {
        return enif_make_badarg(env);
    }

    if (!state) {
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, "NIF state not available", ERL_NIF_UTF8));
    }

#if !DESKTOPUI_HAS_SDL2
    set_last_error(state, "SDL2 not available at compile time");
    return enif_make_tuple2(env, enif_make_atom(env, "error"),
                            enif_make_string(env, "SDL2 not available at compile time", ERL_NIF_UTF8));
#endif

#if DESKTOPUI_HAS_SDL2
    // Extract window_id (integer)
    int window_id;
    if (!enif_get_int(env, argv[0], &window_id)) {
        return enif_make_badarg(env);
    }

    // Find window
    window_resource_t* win = find_window_by_id(state, window_id);
    if (!win) {
        set_last_error(state, "Invalid window ID");
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, "Invalid window ID", ERL_NIF_UTF8));
    }

    // Destroy the window
    if (win->window) {
        SDL_DestroyWindow(win->window);
    }

    // Clear the slot
    win->window = NULL;
    win->window_id = 0;
    win->width = 0;
    win->height = 0;
    win->in_use = 0;
    state->window_count--;

    set_last_error(state, "Window destroyed successfully");
    return enif_make_atom(env, "ok");
#endif
}

/*
 * nif_get_window_size(window_id) -> {:ok, {width, height}} | {:error, reason}
 *
 * Get the current size of a window.
 *
 * Parameters:
 *   - window_id: Window ID (integer)
 *
 * Returns:
 *   - {:ok, {width, height}} on success
 *   - {:error, reason} on failure
 */
static ERL_NIF_TERM nif_get_window_size(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
    (void)argv;  // May be unused if SDL2 not available at compile time
    desktop_ui_nif_state* state = (desktop_ui_nif_state*) enif_priv_data(env);

    if (argc != 1) {
        return enif_make_badarg(env);
    }

    if (!state) {
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, "NIF state not available", ERL_NIF_UTF8));
    }

#if !DESKTOPUI_HAS_SDL2
    set_last_error(state, "SDL2 not available at compile time");
    return enif_make_tuple2(env, enif_make_atom(env, "error"),
                            enif_make_string(env, "SDL2 not available at compile time", ERL_NIF_UTF8));
#endif

#if DESKTOPUI_HAS_SDL2
    // Extract window_id (integer)
    int window_id;
    if (!enif_get_int(env, argv[0], &window_id)) {
        return enif_make_badarg(env);
    }

    // Find window
    window_resource_t* win = find_window_by_id(state, window_id);
    if (!win) {
        set_last_error(state, "Invalid window ID");
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, "Invalid window ID", ERL_NIF_UTF8));
    }

    // Get actual window size from SDL (in case it was resized externally)
    int w, h;
    SDL_GetWindowSize(win->window, &w, &h);

    // Update our cached size
    win->width = w;
    win->height = h;

    // Return tuple with {width, height}
    ERL_NIF_TERM width_term = enif_make_int(env, w);
    ERL_NIF_TERM height_term = enif_make_int(env, h);
    ERL_NIF_TERM size_tuple = enif_make_tuple2(env, width_term, height_term);

    return enif_make_tuple2(env, enif_make_atom(env, "ok"), size_tuple);
#endif
}

/*
 * nif_set_window_size(window_id, width, height) -> :ok | {:error, reason}
 *
 * Resize a window.
 *
 * Parameters:
 *   - window_id: Window ID (integer)
 *   - width: New width in pixels (integer)
 *   - height: New height in pixels (integer)
 *
 * Returns:
 *   - :ok on success
 *   - {:error, reason} on failure
 */
static ERL_NIF_TERM nif_set_window_size(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
    (void)argv;  // May be unused if SDL2 not available at compile time
    desktop_ui_nif_state* state = (desktop_ui_nif_state*) enif_priv_data(env);

    if (argc != 3) {
        return enif_make_badarg(env);
    }

    if (!state) {
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, "NIF state not available", ERL_NIF_UTF8));
    }

#if !DESKTOPUI_HAS_SDL2
    set_last_error(state, "SDL2 not available at compile time");
    return enif_make_tuple2(env, enif_make_atom(env, "error"),
                            enif_make_string(env, "SDL2 not available at compile time", ERL_NIF_UTF8));
#endif

#if DESKTOPUI_HAS_SDL2
    // Extract window_id (integer)
    int window_id;
    if (!enif_get_int(env, argv[0], &window_id)) {
        return enif_make_badarg(env);
    }

    // Extract width (integer)
    int width;
    if (!enif_get_int(env, argv[1], &width)) {
        return enif_make_badarg(env);
    }

    // Extract height (integer)
    int height;
    if (!enif_get_int(env, argv[2], &height)) {
        return enif_make_badarg(env);
    }

    // Validate dimensions
    if (width <= 0 || height <= 0) {
        set_last_error(state, "Invalid window dimensions");
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, "Invalid window dimensions", ERL_NIF_UTF8));
    }

    // Find window
    window_resource_t* win = find_window_by_id(state, window_id);
    if (!win) {
        set_last_error(state, "Invalid window ID");
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, "Invalid window ID", ERL_NIF_UTF8));
    }

    // Set window size
    SDL_SetWindowSize(win->window, width, height);

    // Update our cached size
    win->width = width;
    win->height = height;

    set_last_error(state, "Window size updated successfully");
    return enif_make_atom(env, "ok");
#endif
}

/*
 * nif_set_window_title(window_id, title) -> :ok | {:error, reason}
 *
 * Set the title of a window.
 *
 * Parameters:
 *   - window_id: Window ID (integer)
 *   - title: New title (binary)
 *
 * Returns:
 *   - :ok on success
 *   - {:error, reason} on failure
 */
static ERL_NIF_TERM nif_set_window_title(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
    (void)argv;  // May be unused if SDL2 not available at compile time
    desktop_ui_nif_state* state = (desktop_ui_nif_state*) enif_priv_data(env);

    if (argc != 2) {
        return enif_make_badarg(env);
    }

    if (!state) {
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, "NIF state not available", ERL_NIF_UTF8));
    }

#if !DESKTOPUI_HAS_SDL2
    set_last_error(state, "SDL2 not available at compile time");
    return enif_make_tuple2(env, enif_make_atom(env, "error"),
                            enif_make_string(env, "SDL2 not available at compile time", ERL_NIF_UTF8));
#endif

#if DESKTOPUI_HAS_SDL2
    // Extract window_id (integer)
    int window_id;
    if (!enif_get_int(env, argv[0], &window_id)) {
        return enif_make_badarg(env);
    }

    // Extract title (binary)
    ErlNifBinary title_bin;
    if (!enif_inspect_binary(env, argv[1], &title_bin)) {
        return enif_make_badarg(env);
    }

    // Find window
    window_resource_t* win = find_window_by_id(state, window_id);
    if (!win) {
        set_last_error(state, "Invalid window ID");
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, "Invalid window ID", ERL_NIF_UTF8));
    }

    // Create null-terminated title string
    char title_str[512];
    size_t copy_len = title_bin.size < sizeof(title_str) - 1 ? title_bin.size : sizeof(title_str) - 1;
    memcpy(title_str, title_bin.data, copy_len);
    title_str[copy_len] = '\0';

    // Set window title
    SDL_SetWindowTitle(win->window, title_str);

    set_last_error(state, "Window title updated successfully");
    return enif_make_atom(env, "ok");
#endif
}

/*
 * ============================================================================
 * Renderer and Drawing NIF Implementations
 * ============================================================================
 */

/*
 * nif_create_renderer(window_id) -> {:ok, renderer_id} | {:error, reason}
 *
 * Create a new SDL2 renderer for a window.
 *
 * Parameters:
 *   - window_id: Window ID (integer, returned from create_window)
 *
 * Returns:
 *   - {:ok, renderer_id} on success
 *   - {:error, reason} on failure
 */
static ERL_NIF_TERM nif_create_renderer(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
    (void)argv;  // May be unused if SDL2 not available at compile time
    desktop_ui_nif_state* state = (desktop_ui_nif_state*) enif_priv_data(env);

    if (argc != 1) {
        return enif_make_badarg(env);
    }

    if (!state) {
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, "NIF state not available", ERL_NIF_UTF8));
    }

#if !DESKTOPUI_HAS_SDL2
    set_last_error(state, "SDL2 not available at compile time");
    return enif_make_tuple2(env, enif_make_atom(env, "error"),
                            enif_make_string(env, "SDL2 not available at compile time", ERL_NIF_UTF8));
#endif

#if DESKTOPUI_HAS_SDL2
    // Check if SDL is initialized
    if (!state->sdl_initialized) {
        set_last_error(state, "SDL2 not initialized. Call sdl_init/0 first.");
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, "SDL2 not initialized", ERL_NIF_UTF8));
    }

    // Extract window_id (integer)
    int window_id;
    if (!enif_get_int(env, argv[0], &window_id)) {
        return enif_make_badarg(env);
    }

    // Find window
    window_resource_t* win = find_window_by_id(state, window_id);
    if (!win) {
        set_last_error(state, "Invalid window ID");
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, "Invalid window ID", ERL_NIF_UTF8));
    }

    // Find available renderer slot
    int slot = find_renderer_slot(state);
    if (slot < 0) {
        set_last_error(state, "Maximum number of renderers reached");
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, "Maximum number of renderers reached", ERL_NIF_UTF8));
    }

    // Create the renderer with hardware acceleration and vsync
    // SDL_RENDERER_ACCELERATED = 0x00000002
    // SDL_RENDERER_PRESENTVSYNC = 0x00000004
    Uint32 renderer_flags = SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC;
    SDL_Renderer* renderer = SDL_CreateRenderer(win->window, -1, renderer_flags);

    if (!renderer) {
        set_last_error(state, SDL_GetError());
        ERL_NIF_TERM error_msg = enif_make_string(env, SDL_GetError(), ERL_NIF_UTF8);
        return enif_make_tuple2(env, enif_make_atom(env, "error"), error_msg);
    }

    // Store renderer in state
    state->renderers[slot].renderer = renderer;
    state->renderers[slot].window_id = window_id;
    state->renderers[slot].renderer_id = slot;
    // Initialize draw color to white (255, 255, 255, 255)
    state->renderers[slot].draw_color.r = 255;
    state->renderers[slot].draw_color.g = 255;
    state->renderers[slot].draw_color.b = 255;
    state->renderers[slot].draw_color.a = 255;
    state->renderers[slot].in_use = 1;
    state->renderer_count++;

    set_last_error(state, "Renderer created successfully");

    // Return success with renderer id (slot number for our tracking)
    ERL_NIF_TERM renderer_id_term = enif_make_int(env, slot);
    return enif_make_tuple2(env, enif_make_atom(env, "ok"), renderer_id_term);
#endif
}

/*
 * nif_destroy_renderer(renderer_id) -> :ok | {:error, reason}
 *
 * Destroy an SDL2 renderer and release its resources.
 *
 * Parameters:
 *   - renderer_id: Renderer ID (integer, returned from create_renderer)
 *
 * Returns:
 *   - :ok on success
 *   - {:error, reason} on failure
 */
static ERL_NIF_TERM nif_destroy_renderer(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
    (void)argv;  // May be unused if SDL2 not available at compile time
    desktop_ui_nif_state* state = (desktop_ui_nif_state*) enif_priv_data(env);

    if (argc != 1) {
        return enif_make_badarg(env);
    }

    if (!state) {
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, "NIF state not available", ERL_NIF_UTF8));
    }

#if !DESKTOPUI_HAS_SDL2
    set_last_error(state, "SDL2 not available at compile time");
    return enif_make_tuple2(env, enif_make_atom(env, "error"),
                            enif_make_string(env, "SDL2 not available at compile time", ERL_NIF_UTF8));
#endif

#if DESKTOPUI_HAS_SDL2
    // Extract renderer_id (integer)
    int renderer_id;
    if (!enif_get_int(env, argv[0], &renderer_id)) {
        return enif_make_badarg(env);
    }

    // Find renderer
    renderer_resource_t* ren = find_renderer_by_id(state, renderer_id);
    if (!ren) {
        set_last_error(state, "Invalid renderer ID");
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, "Invalid renderer ID", ERL_NIF_UTF8));
    }

    // Destroy the renderer
    if (ren->renderer) {
        SDL_DestroyRenderer(ren->renderer);
    }

    // Clear the slot
    ren->renderer = NULL;
    ren->window_id = 0;
    ren->renderer_id = 0;
    ren->draw_color.r = 0;
    ren->draw_color.g = 0;
    ren->draw_color.b = 0;
    ren->draw_color.a = 0;
    ren->in_use = 0;
    state->renderer_count--;

    set_last_error(state, "Renderer destroyed successfully");
    return enif_make_atom(env, "ok");
#endif
}

/*
 * nif_set_render_draw_color(renderer_id, r, g, b, a) -> :ok | {:error, reason}
 *
 * Set the draw color for a renderer.
 *
 * Parameters:
 *   - renderer_id: Renderer ID (integer)
 *   - r: Red component (0-255)
 *   - g: Green component (0-255)
 *   - b: Blue component (0-255)
 *   - a: Alpha component (0-255)
 *
 * Returns:
 *   - :ok on success
 *   - {:error, reason} on failure
 */
static ERL_NIF_TERM nif_set_render_draw_color(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
    (void)argv;  // May be unused if SDL2 not available at compile time
    desktop_ui_nif_state* state = (desktop_ui_nif_state*) enif_priv_data(env);

    if (argc != 5) {
        return enif_make_badarg(env);
    }

    if (!state) {
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, "NIF state not available", ERL_NIF_UTF8));
    }

#if !DESKTOPUI_HAS_SDL2
    set_last_error(state, "SDL2 not available at compile time");
    return enif_make_tuple2(env, enif_make_atom(env, "error"),
                            enif_make_string(env, "SDL2 not available at compile time", ERL_NIF_UTF8));
#endif

#if DESKTOPUI_HAS_SDL2
    // Extract renderer_id (integer)
    int renderer_id;
    if (!enif_get_int(env, argv[0], &renderer_id)) {
        return enif_make_badarg(env);
    }

    // Extract color components (integers)
    int r, g, b, a;
    if (!enif_get_int(env, argv[1], &r) ||
        !enif_get_int(env, argv[2], &g) ||
        !enif_get_int(env, argv[3], &b) ||
        !enif_get_int(env, argv[4], &a)) {
        return enif_make_badarg(env);
    }

    // Validate color values
    if (r < 0 || r > 255 || g < 0 || g > 255 || b < 0 || b > 255 || a < 0 || a > 255) {
        set_last_error(state, "Color values must be between 0 and 255");
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, "Color values must be between 0 and 255", ERL_NIF_UTF8));
    }

    // Find renderer
    renderer_resource_t* ren = find_renderer_by_id(state, renderer_id);
    if (!ren) {
        set_last_error(state, "Invalid renderer ID");
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, "Invalid renderer ID", ERL_NIF_UTF8));
    }

    // Set the draw color
    if (SDL_SetRenderDrawColor(ren->renderer, (Uint8)r, (Uint8)g, (Uint8)b, (Uint8)a) < 0) {
        set_last_error(state, SDL_GetError());
        ERL_NIF_TERM error_msg = enif_make_string(env, SDL_GetError(), ERL_NIF_UTF8);
        return enif_make_tuple2(env, enif_make_atom(env, "error"), error_msg);
    }

    // Update cached draw color
    ren->draw_color.r = (Uint8)r;
    ren->draw_color.g = (Uint8)g;
    ren->draw_color.b = (Uint8)b;
    ren->draw_color.a = (Uint8)a;

    set_last_error(state, "Draw color set successfully");
    return enif_make_atom(env, "ok");
#endif
}

/*
 * nif_clear_render(renderer_id) -> :ok | {:error, reason}
 *
 * Clear the renderer target with the current draw color.
 *
 * Parameters:
 *   - renderer_id: Renderer ID (integer)
 *
 * Returns:
 *   - :ok on success
 *   - {:error, reason} on failure
 */
static ERL_NIF_TERM nif_clear_render(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
    (void)argv;  // May be unused if SDL2 not available at compile time
    desktop_ui_nif_state* state = (desktop_ui_nif_state*) enif_priv_data(env);

    if (argc != 1) {
        return enif_make_badarg(env);
    }

    if (!state) {
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, "NIF state not available", ERL_NIF_UTF8));
    }

#if !DESKTOPUI_HAS_SDL2
    set_last_error(state, "SDL2 not available at compile time");
    return enif_make_tuple2(env, enif_make_atom(env, "error"),
                            enif_make_string(env, "SDL2 not available at compile time", ERL_NIF_UTF8));
#endif

#if DESKTOPUI_HAS_SDL2
    // Extract renderer_id (integer)
    int renderer_id;
    if (!enif_get_int(env, argv[0], &renderer_id)) {
        return enif_make_badarg(env);
    }

    // Find renderer
    renderer_resource_t* ren = find_renderer_by_id(state, renderer_id);
    if (!ren) {
        set_last_error(state, "Invalid renderer ID");
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, "Invalid renderer ID", ERL_NIF_UTF8));
    }

    // Clear the renderer
    if (SDL_RenderClear(ren->renderer) < 0) {
        set_last_error(state, SDL_GetError());
        ERL_NIF_TERM error_msg = enif_make_string(env, SDL_GetError(), ERL_NIF_UTF8);
        return enif_make_tuple2(env, enif_make_atom(env, "error"), error_msg);
    }

    set_last_error(state, "Renderer cleared successfully");
    return enif_make_atom(env, "ok");
#endif
}

/*
 * nif_draw_rect(renderer_id, x, y, w, h, {r, g, b, a}) -> :ok | {:error, reason}
 *
 * Draw an outline rectangle.
 *
 * Parameters:
 *   - renderer_id: Renderer ID (integer)
 *   - x: X position (integer)
 *   - y: Y position (integer)
 *   - w: Width (integer)
 *   - h: Height (integer)
 *   - color: Color tuple {r, g, b, a} where each component is 0-255
 *
 * Returns:
 *   - :ok on success
 *   - {:error, reason} on failure
 */
static ERL_NIF_TERM nif_draw_rect(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
    (void)argv;  // May be unused if SDL2 not available at compile time
    desktop_ui_nif_state* state = (desktop_ui_nif_state*) enif_priv_data(env);

    if (argc != 6) {
        return enif_make_badarg(env);
    }

    if (!state) {
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, "NIF state not available", ERL_NIF_UTF8));
    }

#if !DESKTOPUI_HAS_SDL2
    set_last_error(state, "SDL2 not available at compile time");
    return enif_make_tuple2(env, enif_make_atom(env, "error"),
                            enif_make_string(env, "SDL2 not available at compile time", ERL_NIF_UTF8));
#endif

#if DESKTOPUI_HAS_SDL2
    // Extract renderer_id (integer)
    int renderer_id;
    if (!enif_get_int(env, argv[0], &renderer_id)) {
        return enif_make_badarg(env);
    }

    // Extract rectangle position and size
    int x, y, w, h;
    if (!enif_get_int(env, argv[1], &x) ||
        !enif_get_int(env, argv[2], &y) ||
        !enif_get_int(env, argv[3], &w) ||
        !enif_get_int(env, argv[4], &h)) {
        return enif_make_badarg(env);
    }

    // Extract color tuple {r, g, b, a}
    int arity;
    const ERL_NIF_TERM* color_tuple;
    if (!enif_get_tuple(env, argv[5], &arity, &color_tuple) || arity != 4) {
        return enif_make_badarg(env);
    }

    int r, g, b, a;
    if (!enif_get_int(env, color_tuple[0], &r) ||
        !enif_get_int(env, color_tuple[1], &g) ||
        !enif_get_int(env, color_tuple[2], &b) ||
        !enif_get_int(env, color_tuple[3], &a)) {
        return enif_make_badarg(env);
    }

    // Validate color values
    if (r < 0 || r > 255 || g < 0 || g > 255 || b < 0 || b > 255 || a < 0 || a > 255) {
        set_last_error(state, "Color values must be between 0 and 255");
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, "Color values must be between 0 and 255", ERL_NIF_UTF8));
    }

    // Find renderer
    renderer_resource_t* ren = find_renderer_by_id(state, renderer_id);
    if (!ren) {
        set_last_error(state, "Invalid renderer ID");
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, "Invalid renderer ID", ERL_NIF_UTF8));
    }

    // Save current draw color
    SDL_Color saved_color = ren->draw_color;

    // Set new draw color
    if (SDL_SetRenderDrawColor(ren->renderer, (Uint8)r, (Uint8)g, (Uint8)b, (Uint8)a) < 0) {
        set_last_error(state, SDL_GetError());
        ERL_NIF_TERM error_msg = enif_make_string(env, SDL_GetError(), ERL_NIF_UTF8);
        return enif_make_tuple2(env, enif_make_atom(env, "error"), error_msg);
    }

    // Draw the rectangle
    SDL_Rect rect = {x, y, w, h};
    int result = SDL_RenderDrawRect(ren->renderer, &rect);

    // Restore original draw color
    SDL_SetRenderDrawColor(ren->renderer, saved_color.r, saved_color.g, saved_color.b, saved_color.a);

    if (result < 0) {
        set_last_error(state, SDL_GetError());
        ERL_NIF_TERM error_msg = enif_make_string(env, SDL_GetError(), ERL_NIF_UTF8);
        return enif_make_tuple2(env, enif_make_atom(env, "error"), error_msg);
    }

    set_last_error(state, "Rectangle drawn successfully");
    return enif_make_atom(env, "ok");
#endif
}

/*
 * nif_fill_rect(renderer_id, x, y, w, h, {r, g, b, a}) -> :ok | {:error, reason}
 *
 * Draw a filled rectangle.
 *
 * Parameters:
 *   - renderer_id: Renderer ID (integer)
 *   - x: X position (integer)
 *   - y: Y position (integer)
 *   - w: Width (integer)
 *   - h: Height (integer)
 *   - color: Color tuple {r, g, b, a} where each component is 0-255
 *
 * Returns:
 *   - :ok on success
 *   - {:error, reason} on failure
 */
static ERL_NIF_TERM nif_fill_rect(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
    (void)argv;  // May be unused if SDL2 not available at compile time
    desktop_ui_nif_state* state = (desktop_ui_nif_state*) enif_priv_data(env);

    if (argc != 6) {
        return enif_make_badarg(env);
    }

    if (!state) {
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, "NIF state not available", ERL_NIF_UTF8));
    }

#if !DESKTOPUI_HAS_SDL2
    set_last_error(state, "SDL2 not available at compile time");
    return enif_make_tuple2(env, enif_make_atom(env, "error"),
                            enif_make_string(env, "SDL2 not available at compile time", ERL_NIF_UTF8));
#endif

#if DESKTOPUI_HAS_SDL2
    // Extract renderer_id (integer)
    int renderer_id;
    if (!enif_get_int(env, argv[0], &renderer_id)) {
        return enif_make_badarg(env);
    }

    // Extract rectangle position and size
    int x, y, w, h;
    if (!enif_get_int(env, argv[1], &x) ||
        !enif_get_int(env, argv[2], &y) ||
        !enif_get_int(env, argv[3], &w) ||
        !enif_get_int(env, argv[4], &h)) {
        return enif_make_badarg(env);
    }

    // Extract color tuple {r, g, b, a}
    int arity;
    const ERL_NIF_TERM* color_tuple;
    if (!enif_get_tuple(env, argv[5], &arity, &color_tuple) || arity != 4) {
        return enif_make_badarg(env);
    }

    int r, g, b, a;
    if (!enif_get_int(env, color_tuple[0], &r) ||
        !enif_get_int(env, color_tuple[1], &g) ||
        !enif_get_int(env, color_tuple[2], &b) ||
        !enif_get_int(env, color_tuple[3], &a)) {
        return enif_make_badarg(env);
    }

    // Validate color values
    if (r < 0 || r > 255 || g < 0 || g > 255 || b < 0 || b > 255 || a < 0 || a > 255) {
        set_last_error(state, "Color values must be between 0 and 255");
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, "Color values must be between 0 and 255", ERL_NIF_UTF8));
    }

    // Find renderer
    renderer_resource_t* ren = find_renderer_by_id(state, renderer_id);
    if (!ren) {
        set_last_error(state, "Invalid renderer ID");
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, "Invalid renderer ID", ERL_NIF_UTF8));
    }

    // Save current draw color
    SDL_Color saved_color = ren->draw_color;

    // Set new draw color
    if (SDL_SetRenderDrawColor(ren->renderer, (Uint8)r, (Uint8)g, (Uint8)b, (Uint8)a) < 0) {
        set_last_error(state, SDL_GetError());
        ERL_NIF_TERM error_msg = enif_make_string(env, SDL_GetError(), ERL_NIF_UTF8);
        return enif_make_tuple2(env, enif_make_atom(env, "error"), error_msg);
    }

    // Draw the filled rectangle
    SDL_Rect rect = {x, y, w, h};
    int result = SDL_RenderFillRect(ren->renderer, &rect);

    // Restore original draw color
    SDL_SetRenderDrawColor(ren->renderer, saved_color.r, saved_color.g, saved_color.b, saved_color.a);

    if (result < 0) {
        set_last_error(state, SDL_GetError());
        ERL_NIF_TERM error_msg = enif_make_string(env, SDL_GetError(), ERL_NIF_UTF8);
        return enif_make_tuple2(env, enif_make_atom(env, "error"), error_msg);
    }

    set_last_error(state, "Filled rectangle drawn successfully");
    return enif_make_atom(env, "ok");
#endif
}

/*
 * nif_present_render(renderer_id) -> :ok | {:error, reason}
 *
 * Present the rendered content to the screen.
 * This swaps the buffers to display what has been rendered.
 *
 * Parameters:
 *   - renderer_id: Renderer ID (integer)
 *
 * Returns:
 *   - :ok on success
 *   - {:error, reason} on failure
 */
static ERL_NIF_TERM nif_present_render(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
    (void)argv;  // May be unused if SDL2 not available at compile time
    desktop_ui_nif_state* state = (desktop_ui_nif_state*) enif_priv_data(env);

    if (argc != 1) {
        return enif_make_badarg(env);
    }

    if (!state) {
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, "NIF state not available", ERL_NIF_UTF8));
    }

#if !DESKTOPUI_HAS_SDL2
    set_last_error(state, "SDL2 not available at compile time");
    return enif_make_tuple2(env, enif_make_atom(env, "error"),
                            enif_make_string(env, "SDL2 not available at compile time", ERL_NIF_UTF8));
#endif

#if DESKTOPUI_HAS_SDL2
    // Extract renderer_id (integer)
    int renderer_id;
    if (!enif_get_int(env, argv[0], &renderer_id)) {
        return enif_make_badarg(env);
    }

    // Find renderer
    renderer_resource_t* ren = find_renderer_by_id(state, renderer_id);
    if (!ren) {
        set_last_error(state, "Invalid renderer ID");
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, "Invalid renderer ID", ERL_NIF_UTF8));
    }

    // Present the rendered content
    SDL_RenderPresent(ren->renderer);

    set_last_error(state, "Render presented successfully");
    return enif_make_atom(env, "ok");
#endif
}

/*
 * ============================================================================
 * NIF Function Array
 * ============================================================================
 *
 * This array defines all the functions that are exported to Elixir.
 * The order must match the order in DesktopUI.Graphics module.
 */

static ErlNifFunc nif_funcs[] = {
    {"nif_init", 0, nif_initialize, 0},
    {"nif_get_version", 0, nif_get_version, 0},
    {"nif_get_error", 0, nif_get_error, 0},
    {"nif_is_initialized", 0, nif_is_initialized, 0},
    {"nif_sdl_init", 0, nif_sdl_init, 0},
    {"nif_create_window", 4, nif_create_window, 0},
    {"nif_destroy_window", 1, nif_destroy_window, 0},
    {"nif_get_window_size", 1, nif_get_window_size, 0},
    {"nif_set_window_size", 3, nif_set_window_size, 0},
    {"nif_set_window_title", 2, nif_set_window_title, 0},
    {"nif_create_renderer", 1, nif_create_renderer, 0},
    {"nif_destroy_renderer", 1, nif_destroy_renderer, 0},
    {"nif_set_render_draw_color", 5, nif_set_render_draw_color, 0},
    {"nif_clear_render", 1, nif_clear_render, 0},
    {"nif_draw_rect", 6, nif_draw_rect, 0},
    {"nif_fill_rect", 6, nif_fill_rect, 0},
    {"nif_present_render", 1, nif_present_render, 0}
};

/*
 * ============================================================================
 * NIF Initialization Entry Point
 * ============================================================================
 *
 * This macro defines the entry point for the NIF library.
 * The name must match the Elixir module that loads this NIF: Elixir.DesktopUI.Graphics
 */

ERL_NIF_INIT(Elixir.DesktopUI.Graphics, nif_funcs, load, reload, upgrade, unload)

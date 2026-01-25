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

/* SDL type definitions (when SDL2 is not available) */
typedef uint8_t Uint8;
typedef uint16_t Uint16;
typedef uint32_t Uint32;
typedef uint64_t Uint64;
typedef int32_t Sint32;

typedef struct SDL_Window SDL_Window;
typedef struct SDL_Renderer SDL_Renderer;
struct SDL_Window {
    int dummy;
};
struct SDL_Renderer {
    int dummy;
};

/* Forward type declarations for event structures */
typedef struct {
    int scancode;
    int sym;
    Uint16 mod;
    Uint32 unused;
} SDL_Keysym;

typedef struct {
    Uint8 b, g, r, a;
} SDL_Color;

typedef struct {
    int x, y, w, h;
} SDL_Rect;

/* Event structure definition */
typedef struct SDL_Event {
    Uint32 type;
    union {
        struct {
            Uint32 timestamp;
            Uint32 windowID;
            Uint8 state;
            Uint8 repeat;
            Uint8 padding2;
            Uint8 padding3;
            SDL_Keysym keysym;
        } key;
        struct {
            Uint32 timestamp;
            Uint32 windowID;
            Uint32 which;
            Uint8 state;
            Uint8 button;
            Uint8 padding1;
            Uint8 padding2;
            int x;
            int y;
        } button;
        struct {
            Uint32 timestamp;
            Uint32 windowID;
            Uint32 which;
            Uint32 state;
            int x;
            int y;
            int xrel;
            int yrel;
        } motion;
        struct {
            Uint32 timestamp;
            Uint32 windowID;
            Uint8 event;
            Uint8 padding1;
            Uint8 padding2;
            Uint8 padding3;
            int data1;
            int data2;
        } window;
    } padding;
} SDL_Event;

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

/* Event stubs */
#define SDL_QUIT 0x100
#define SDL_KEYDOWN 0x300
#define SDL_KEYUP 0x301
#define SDL_MOUSEBUTTONDOWN 0x401
#define SDL_MOUSEBUTTONUP 0x402
#define SDL_MOUSEMOTION 0x400
#define SDL_WINDOWEVENT 0x200

#define SDLK_UNKNOWN 0
#define SDLK_BACKSPACE 8
#define SDLK_TAB 9
#define SDLK_RETURN 13
#define SDLK_ESCAPE 27
#define SDLK_SPACE 32
#define SDLK_EXCLAIM 33
#define SDLK_QUOTEDBL 34
#define SDLK_HASH 35
#define SDLK_DOLLAR 36
#define SDLK_AMPERSAND 37
#define SDLK_QUOTE 39
#define SDLK_LEFTPAREN 40
#define SDLK_RIGHTPAREN 41
#define SDLK_ASTERISK 42
#define SDLK_PLUS 43
#define SDLK_COMMA 44
#define SDLK_MINUS 45
#define SDLK_PERIOD 46
#define SDLK_SLASH 47
#define SDLK_0 48
#define SDLK_1 49
#define SDLK_2 50
#define SDLK_3 51
#define SDLK_4 52
#define SDLK_5 53
#define SDLK_6 54
#define SDLK_7 55
#define SDLK_8 56
#define SDLK_9 57
#define SDLK_COLON 58
#define SDLK_SEMICOLON 59
#define SDLK_LESS 60
#define SDLK_EQUALS 61
#define SDLK_GREATER 62
#define SDLK_QUESTION 63
#define SDLK_AT 64
#define SDLK_LEFTBRACKET 91
#define SDLK_BACKSLASH 92
#define SDLK_RIGHTBRACKET 93
#define SDLK_CARET 94
#define SDLK_UNDERSCORE 95
#define SDLK_BACKQUOTE 96
#define SDLK_a 97
#define SDLK_b 98
#define SDLK_c 99
#define SDLK_d 100
#define SDLK_e 101
#define SDLK_f 102
#define SDLK_g 103
#define SDLK_h 104
#define SDLK_i 105
#define SDLK_j 106
#define SDLK_k 107
#define SDLK_l 108
#define SDLK_m 109
#define SDLK_n 110
#define SDLK_o 111
#define SDLK_p 112
#define SDLK_q 113
#define SDLK_r 114
#define SDLK_s 115
#define SDLK_t 116
#define SDLK_u 117
#define SDLK_v 118
#define SDLK_w 119
#define SDLK_x 120
#define SDLK_y 121
#define SDLK_z 122
#define SDLK_DELETE 127

#define KMOD_NONE 0x0000
#define KMOD_LSHIFT 0x0001
#define KMOD_RSHIFT 0x0002
#define KMOD_LCTRL 0x0040
#define KMOD_RCTRL 0x0080
#define KMOD_LALT 0x0100
#define KMOD_RALT 0x0200
#define KMOD_LGUI 0x0400
#define KMOD_RGUI 0x0800
#define KMOD_SHIFT 0x0003
#define KMOD_CTRL 0x00C0
#define KMOD_ALT 0x0300
#define KMOD_GUI 0x0C00

#define SDL_BUTTON_LEFT 1
#define SDL_BUTTON_MIDDLE 2
#define SDL_BUTTON_RIGHT 3
#define SDL_BUTTON_X1 4
#define SDL_BUTTON_X2 5

#define SDL_WINDOWEVENT_SHOWN 1
#define SDL_WINDOWEVENT_HIDDEN 2
#define SDL_WINDOWEVENT_EXPOSED 3
#define SDL_WINDOWEVENT_MOVED 4
#define SDL_WINDOWEVENT_RESIZED 5
#define SDL_WINDOWEVENT_SIZE_CHANGED 6
#define SDL_WINDOWEVENT_MINIMIZED 7
#define SDL_WINDOWEVENT_MAXIMIZED 8
#define SDL_WINDOWEVENT_RESTORED 9
#define SDL_WINDOWEVENT_ENTER 10
#define SDL_WINDOWEVENT_LEAVE 11
#define SDL_WINDOWEVENT_FOCUS_GAINED 12
#define SDL_WINDOWEVENT_FOCUS_LOST 13
#define SDL_WINDOWEVENT_CLOSE 14

static inline int SDL_PollEvent(SDL_Event* event) {
    (void)event;
    return 0;
}
static inline int SDL_WaitEventTimeout(SDL_Event* event, int timeout) {
    (void)event; (void)timeout;
    return 0;
}
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

/* Slot management mutex
 * Protects access to the in_use flags in windows[] and renderers[] arrays.
 * This prevents race conditions where two concurrent NIF calls could allocate
 * the same slot, causing resource corruption.
 */
static ErlNifMutex* slot_mutex = NULL;

/* Maximum window dimensions - 8K resolution (7680x4320)
 * These limits prevent integer overflow and protect against malformed input.
 * Most practical use cases will be far below these limits.
 */
#define MAX_WINDOW_WIDTH 7680
#define MAX_WINDOW_HEIGHT 4320

/* Maximum window title length
 * SDL2 doesn't enforce a strict limit, but reasonable bounds prevent:
 * - Memory exhaustion from extremely long titles
 * - Display issues with truncated titles
 * - Potential buffer overflows in platform-specific window managers
 */
#define MAX_WINDOW_TITLE_LENGTH 1024

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

/* Event polling functions */
static ERL_NIF_TERM nif_poll_event(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
static ERL_NIF_TERM nif_wait_event(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);

/* Helper functions */
static void set_last_error(desktop_ui_nif_state* state, const char* error);
static int allocate_window_slot(desktop_ui_nif_state* state);
static void free_window_slot(desktop_ui_nif_state* state, int slot);
static window_resource_t* find_window_by_id(desktop_ui_nif_state* state, int window_id);
static int allocate_renderer_slot(desktop_ui_nif_state* state);
static void free_renderer_slot(desktop_ui_nif_state* state, int slot);
static renderer_resource_t* find_renderer_by_id(desktop_ui_nif_state* state, int renderer_id);

#if DESKTOPUI_HAS_SDL2
static ERL_NIF_TERM keycode_to_atom(ErlNifEnv* env, int keycode);
static ERL_NIF_TERM modifiers_to_map(ErlNifEnv* env, Uint16 mod);
static ERL_NIF_TERM translate_sdl_event(ErlNifEnv* env, SDL_Event* event);
#endif

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

    // Create slot management mutex
    slot_mutex = enif_mutex_create("desktop_ui_slots");
    if (!slot_mutex) {
        return 1;  // Failure - cannot create mutex
    }

    desktop_ui_nif_state* state = (desktop_ui_nif_state*) enif_alloc(sizeof(desktop_ui_nif_state));
    if (!state) {
        enif_mutex_destroy(slot_mutex);
        slot_mutex = NULL;
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

    // Destroy slot management mutex
    if (slot_mutex) {
        enif_mutex_destroy(slot_mutex);
        slot_mutex = NULL;
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
 * Helper: Set error message with operation context
 * Formats error as: "<operation> failed: <reason> (value: <value>)"
 * This provides more context for debugging than generic error messages
 */
static void set_error_with_context(desktop_ui_nif_state* state,
                                   const char* operation,
                                   const char* reason,
                                   int value)
{
    if (!state) {
        return;
    }

    char error_buf[512];
    if (value >= 0) {
        snprintf(error_buf, sizeof(error_buf),
                 "%s failed: %s (value: %d)",
                 operation, reason, value);
    } else {
        snprintf(error_buf, sizeof(error_buf),
                 "%s failed: %s",
                 operation, reason);
    }

    set_last_error(state, error_buf);
}

/*
 * Helper: Set error message with string context
 * Formats error as: "<operation> failed: <reason>: <detail>"
 */
static void set_error_with_string_context(desktop_ui_nif_state* state,
                                         const char* operation,
                                         const char* reason,
                                         const char* detail)
{
    if (!state) {
        return;
    }

    char error_buf[512];
    if (detail) {
        snprintf(error_buf, sizeof(error_buf),
                 "%s failed: %s: %s",
                 operation, reason, detail);
    } else {
        snprintf(error_buf, sizeof(error_buf),
                 "%s failed: %s",
                 operation, reason);
    }

    set_last_error(state, error_buf);
}

/*
 * Helper: Allocate an available window slot (atomic)
 * Returns slot index or -1 if full
 * Thread-safe: uses mutex to prevent race conditions
 */
#if !DESKTOPUI_HAS_SDL2
__attribute__((unused))
#endif
static int allocate_window_slot(desktop_ui_nif_state* state)
{
    if (!state) {
        return -1;
    }

    enif_mutex_lock(slot_mutex);

    for (int i = 0; i < MAX_WINDOWS; i++) {
        if (!state->windows[i].in_use) {
            // Atomically mark as used
            state->windows[i].in_use = 1;
            enif_mutex_unlock(slot_mutex);
            return i;
        }
    }

    enif_mutex_unlock(slot_mutex);
    return -1;  // No available slots
}

/*
 * Helper: Free a window slot (atomic)
 * Thread-safe: uses mutex to prevent race conditions
 */
#if !DESKTOPUI_HAS_SDL2
__attribute__((unused))
#endif
static void free_window_slot(desktop_ui_nif_state* state, int slot)
{
    if (!state || slot < 0 || slot >= MAX_WINDOWS) {
        return;
    }

    enif_mutex_lock(slot_mutex);
    state->windows[slot].in_use = 0;
    enif_mutex_unlock(slot_mutex);
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
 * Helper: Allocate an available renderer slot (atomic)
 * Returns slot index or -1 if full
 * Thread-safe: uses mutex to prevent race conditions
 */
#if !DESKTOPUI_HAS_SDL2
__attribute__((unused))
#endif
static int allocate_renderer_slot(desktop_ui_nif_state* state)
{
    if (!state) {
        return -1;
    }

    enif_mutex_lock(slot_mutex);

    for (int i = 0; i < MAX_RENDERERS; i++) {
        if (!state->renderers[i].in_use) {
            // Atomically mark as used
            state->renderers[i].in_use = 1;
            enif_mutex_unlock(slot_mutex);
            return i;
        }
    }

    enif_mutex_unlock(slot_mutex);
    return -1;  // No available slots
}

/*
 * Helper: Free a renderer slot (atomic)
 * Thread-safe: uses mutex to prevent race conditions
 */
#if !DESKTOPUI_HAS_SDL2
__attribute__((unused))
#endif
static void free_renderer_slot(desktop_ui_nif_state* state, int slot)
{
    if (!state || slot < 0 || slot >= MAX_RENDERERS) {
        return;
    }

    enif_mutex_lock(slot_mutex);
    state->renderers[slot].in_use = 0;
    enif_mutex_unlock(slot_mutex);
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

    // Validate title is not empty
    if (title_bin.size == 0) {
        set_last_error(state, "Window title cannot be empty");
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, "Window title cannot be empty", ERL_NIF_UTF8));
    }

    // Validate title length
    if (title_bin.size >= MAX_WINDOW_TITLE_LENGTH) {
        char error_msg[256];
        snprintf(error_msg, sizeof(error_msg),
                 "Window title exceeds maximum length (actual: %zu bytes, max: %d bytes)",
                 title_bin.size, MAX_WINDOW_TITLE_LENGTH);
        set_last_error(state, error_msg);
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, error_msg, ERL_NIF_UTF8));
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
        set_error_with_context(state, "window operation",
                              "dimensions must be positive",
                              width <= 0 ? width : height);
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, state->last_error, ERL_NIF_UTF8));
    }

    // Validate upper bounds to prevent integer overflow
    if (width > MAX_WINDOW_WIDTH || height > MAX_WINDOW_HEIGHT) {
        char error_msg[256];
        snprintf(error_msg, sizeof(error_msg),
                 "Window dimensions exceed maximum (width: %d, max: %d, height: %d, max: %d)",
                 width, MAX_WINDOW_WIDTH, height, MAX_WINDOW_HEIGHT);
        set_last_error(state, error_msg);
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, error_msg, ERL_NIF_UTF8));
    }

    // Allocate available window slot (atomic)
    int slot = allocate_window_slot(state);
    if (slot < 0) {
        set_last_error(state, "Maximum number of windows reached");
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, "Maximum number of windows reached", ERL_NIF_UTF8));
    }

    // Create null-terminated title string
    // Buffer size is MAX_WINDOW_TITLE_LENGTH + 1 for null terminator
    char title_str[MAX_WINDOW_TITLE_LENGTH + 1];
    memcpy(title_str, title_bin.data, title_bin.size);
    title_str[title_bin.size] = '\0';

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
    // Note: in_use is already set to 1 by allocate_window_slot()
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
        set_error_with_context(state, "window operation", "invalid window ID", window_id);
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, state->last_error, ERL_NIF_UTF8));
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
    // Free slot atomically (sets in_use to 0)
    free_window_slot(state, window_id);
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
        set_error_with_context(state, "window operation", "invalid window ID", window_id);
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, state->last_error, ERL_NIF_UTF8));
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
        set_error_with_context(state, "window operation",
                              "dimensions must be positive",
                              width <= 0 ? width : height);
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, state->last_error, ERL_NIF_UTF8));
    }

    // Validate upper bounds to prevent integer overflow
    if (width > MAX_WINDOW_WIDTH || height > MAX_WINDOW_HEIGHT) {
        char error_msg[256];
        snprintf(error_msg, sizeof(error_msg),
                 "Window dimensions exceed maximum (width: %d, max: %d, height: %d, max: %d)",
                 width, MAX_WINDOW_WIDTH, height, MAX_WINDOW_HEIGHT);
        set_last_error(state, error_msg);
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, error_msg, ERL_NIF_UTF8));
    }

    // Find window
    window_resource_t* win = find_window_by_id(state, window_id);
    if (!win) {
        set_error_with_context(state, "window operation", "invalid window ID", window_id);
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, state->last_error, ERL_NIF_UTF8));
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

    // Validate title is not empty
    if (title_bin.size == 0) {
        set_last_error(state, "Window title cannot be empty");
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, "Window title cannot be empty", ERL_NIF_UTF8));
    }

    // Validate title length
    if (title_bin.size >= MAX_WINDOW_TITLE_LENGTH) {
        char error_msg[256];
        snprintf(error_msg, sizeof(error_msg),
                 "Window title exceeds maximum length (actual: %zu bytes, max: %d bytes)",
                 title_bin.size, MAX_WINDOW_TITLE_LENGTH);
        set_last_error(state, error_msg);
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, error_msg, ERL_NIF_UTF8));
    }

    // Find window
    window_resource_t* win = find_window_by_id(state, window_id);
    if (!win) {
        set_error_with_context(state, "window operation", "invalid window ID", window_id);
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, state->last_error, ERL_NIF_UTF8));
    }

    // Create null-terminated title string
    // Buffer size is MAX_WINDOW_TITLE_LENGTH + 1 for null terminator
    char title_str[MAX_WINDOW_TITLE_LENGTH + 1];
    memcpy(title_str, title_bin.data, title_bin.size);
    title_str[title_bin.size] = '\0';

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
        set_error_with_context(state, "window operation", "invalid window ID", window_id);
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, state->last_error, ERL_NIF_UTF8));
    }

    // Allocate available renderer slot (atomic)
    int slot = allocate_renderer_slot(state);
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
    // Note: in_use is already set to 1 by allocate_renderer_slot()
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
        set_error_with_context(state, "renderer operation", "invalid renderer ID", renderer_id);
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, state->last_error, ERL_NIF_UTF8));
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
    // Free slot atomically (sets in_use to 0)
    free_renderer_slot(state, renderer_id);
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
        set_error_with_string_context(state, "color operation",
                                      "color values must be between 0 and 255",
                                      NULL);
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, state->last_error, ERL_NIF_UTF8));
    }

    // Find renderer
    renderer_resource_t* ren = find_renderer_by_id(state, renderer_id);
    if (!ren) {
        set_error_with_context(state, "renderer operation", "invalid renderer ID", renderer_id);
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, state->last_error, ERL_NIF_UTF8));
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
        set_error_with_context(state, "renderer operation", "invalid renderer ID", renderer_id);
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, state->last_error, ERL_NIF_UTF8));
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
        set_error_with_string_context(state, "color operation",
                                      "color values must be between 0 and 255",
                                      NULL);
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, state->last_error, ERL_NIF_UTF8));
    }

    // Find renderer
    renderer_resource_t* ren = find_renderer_by_id(state, renderer_id);
    if (!ren) {
        set_error_with_context(state, "renderer operation", "invalid renderer ID", renderer_id);
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, state->last_error, ERL_NIF_UTF8));
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
        set_error_with_string_context(state, "color operation",
                                      "color values must be between 0 and 255",
                                      NULL);
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, state->last_error, ERL_NIF_UTF8));
    }

    // Find renderer
    renderer_resource_t* ren = find_renderer_by_id(state, renderer_id);
    if (!ren) {
        set_error_with_context(state, "renderer operation", "invalid renderer ID", renderer_id);
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, state->last_error, ERL_NIF_UTF8));
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
        set_error_with_context(state, "renderer operation", "invalid renderer ID", renderer_id);
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, state->last_error, ERL_NIF_UTF8));
    }

    // Present the rendered content
    SDL_RenderPresent(ren->renderer);

    set_last_error(state, "Render presented successfully");
    return enif_make_atom(env, "ok");
#endif
}

/*
 * ============================================================================
 * Event Polling and Translation NIF Implementations
 * ============================================================================
 */

/*
 * Helper: Convert SDL keycode to Elixir atom
 * Returns atom like :key_a, :key_escape, etc.
 */
#if DESKTOPUI_HAS_SDL2
static ERL_NIF_TERM keycode_to_atom(ErlNifEnv* env, int keycode)
{
    switch (keycode) {
        /* Letters */
        case SDLK_a: return enif_make_atom(env, "key_a");
        case SDLK_b: return enif_make_atom(env, "key_b");
        case SDLK_c: return enif_make_atom(env, "key_c");
        case SDLK_d: return enif_make_atom(env, "key_d");
        case SDLK_e: return enif_make_atom(env, "key_e");
        case SDLK_f: return enif_make_atom(env, "key_f");
        case SDLK_g: return enif_make_atom(env, "key_g");
        case SDLK_h: return enif_make_atom(env, "key_h");
        case SDLK_i: return enif_make_atom(env, "key_i");
        case SDLK_j: return enif_make_atom(env, "key_j");
        case SDLK_k: return enif_make_atom(env, "key_k");
        case SDLK_l: return enif_make_atom(env, "key_l");
        case SDLK_m: return enif_make_atom(env, "key_m");
        case SDLK_n: return enif_make_atom(env, "key_n");
        case SDLK_o: return enif_make_atom(env, "key_o");
        case SDLK_p: return enif_make_atom(env, "key_p");
        case SDLK_q: return enif_make_atom(env, "key_q");
        case SDLK_r: return enif_make_atom(env, "key_r");
        case SDLK_s: return enif_make_atom(env, "key_s");
        case SDLK_t: return enif_make_atom(env, "key_t");
        case SDLK_u: return enif_make_atom(env, "key_u");
        case SDLK_v: return enif_make_atom(env, "key_v");
        case SDLK_w: return enif_make_atom(env, "key_w");
        case SDLK_x: return enif_make_atom(env, "key_x");
        case SDLK_y: return enif_make_atom(env, "key_y");
        case SDLK_z: return enif_make_atom(env, "key_z");

        /* Numbers */
        case SDLK_0: return enif_make_atom(env, "key_0");
        case SDLK_1: return enif_make_atom(env, "key_1");
        case SDLK_2: return enif_make_atom(env, "key_2");
        case SDLK_3: return enif_make_atom(env, "key_3");
        case SDLK_4: return enif_make_atom(env, "key_4");
        case SDLK_5: return enif_make_atom(env, "key_5");
        case SDLK_6: return enif_make_atom(env, "key_6");
        case SDLK_7: return enif_make_atom(env, "key_7");
        case SDLK_8: return enif_make_atom(env, "key_8");
        case SDLK_9: return enif_make_atom(env, "key_9");

        /* Special keys */
        case SDLK_BACKSPACE: return enif_make_atom(env, "key_backspace");
        case SDLK_TAB: return enif_make_atom(env, "key_tab");
        case SDLK_RETURN: return enif_make_atom(env, "key_return");
        case SDLK_ESCAPE: return enif_make_atom(env, "key_escape");
        case SDLK_SPACE: return enif_make_atom(env, "key_space");
        case SDLK_DELETE: return enif_make_atom(env, "key_delete");

        /* Punctuation and symbols */
        case SDLK_EXCLAIM: return enif_make_atom(env, "key_exclaim");
        case SDLK_QUOTEDBL: return enif_make_atom(env, "key_quotedbl");
        case SDLK_HASH: return enif_make_atom(env, "key_hash");
        case SDLK_DOLLAR: return enif_make_atom(env, "key_dollar");
        case SDLK_AMPERSAND: return enif_make_atom(env, "key_ampersand");
        case SDLK_QUOTE: return enif_make_atom(env, "key_quote");
        case SDLK_LEFTPAREN: return enif_make_atom(env, "key_leftparen");
        case SDLK_RIGHTPAREN: return enif_make_atom(env, "key_rightparen");
        case SDLK_ASTERISK: return enif_make_atom(env, "key_asterisk");
        case SDLK_PLUS: return enif_make_atom(env, "key_plus");
        case SDLK_COMMA: return enif_make_atom(env, "key_comma");
        case SDLK_MINUS: return enif_make_atom(env, "key_minus");
        case SDLK_PERIOD: return enif_make_atom(env, "key_period");
        case SDLK_SLASH: return enif_make_atom(env, "key_slash");
        case SDLK_COLON: return enif_make_atom(env, "key_colon");
        case SDLK_SEMICOLON: return enif_make_atom(env, "key_semicolon");
        case SDLK_LESS: return enif_make_atom(env, "key_less");
        case SDLK_EQUALS: return enif_make_atom(env, "key_equals");
        case SDLK_GREATER: return enif_make_atom(env, "key_greater");
        case SDLK_QUESTION: return enif_make_atom(env, "key_question");
        case SDLK_AT: return enif_make_atom(env, "key_at");
        case SDLK_LEFTBRACKET: return enif_make_atom(env, "key_leftbracket");
        case SDLK_BACKSLASH: return enif_make_atom(env, "key_backslash");
        case SDLK_RIGHTBRACKET: return enif_make_atom(env, "key_rightbracket");
        case SDLK_CARET: return enif_make_atom(env, "key_caret");
        case SDLK_UNDERSCORE: return enif_make_atom(env, "key_underscore");
        case SDLK_BACKQUOTE: return enif_make_atom(env, "key_backquote");

        default: return enif_make_atom(env, "key_unknown");
    }
}

/*
 * Helper: Convert SDL modifier state to Elixir map
 * Returns %{shift: boolean(), ctrl: boolean(), alt: boolean(), gui: boolean()}
 */
static ERL_NIF_TERM modifiers_to_map(ErlNifEnv* env, Uint16 mod)
{
    ERL_NIF_TERM map = enif_make_new_map(env);

    // Shift
    ERL_NIF_TERM shift_val = (mod & KMOD_SHIFT) ? enif_make_atom(env, "true") : enif_make_atom(env, "false");
    enif_make_map_put(env, map, enif_make_atom(env, "shift"), shift_val, &map);

    // Ctrl
    ERL_NIF_TERM ctrl_val = (mod & KMOD_CTRL) ? enif_make_atom(env, "true") : enif_make_atom(env, "false");
    enif_make_map_put(env, map, enif_make_atom(env, "ctrl"), ctrl_val, &map);

    // Alt
    ERL_NIF_TERM alt_val = (mod & KMOD_ALT) ? enif_make_atom(env, "true") : enif_make_atom(env, "false");
    enif_make_map_put(env, map, enif_make_atom(env, "alt"), alt_val, &map);

    // Gui (Windows/Command key)
    ERL_NIF_TERM gui_val = (mod & KMOD_GUI) ? enif_make_atom(env, "true") : enif_make_atom(env, "false");
    enif_make_map_put(env, map, enif_make_atom(env, "gui"), gui_val, &map);

    return map;
}

/*
 * Helper: Convert SDL button to Elixir atom
 */
static ERL_NIF_TERM button_to_atom(ErlNifEnv* env, Uint8 button)
{
    switch (button) {
        case SDL_BUTTON_LEFT: return enif_make_atom(env, "left");
        case SDL_BUTTON_MIDDLE: return enif_make_atom(env, "middle");
        case SDL_BUTTON_RIGHT: return enif_make_atom(env, "right");
        case SDL_BUTTON_X1: return enif_make_atom(env, "x1");
        case SDL_BUTTON_X2: return enif_make_atom(env, "x2");
        default: return enif_make_atom(env, "unknown");
    }
}

/*
 * Helper: Convert SDL window event to Elixir atom
 */
static ERL_NIF_TERM window_event_to_atom(ErlNifEnv* env, Uint8 event)
{
    switch (event) {
        case SDL_WINDOWEVENT_SHOWN: return enif_make_atom(env, "shown");
        case SDL_WINDOWEVENT_HIDDEN: return enif_make_atom(env, "hidden");
        case SDL_WINDOWEVENT_EXPOSED: return enif_make_atom(env, "exposed");
        case SDL_WINDOWEVENT_MOVED: return enif_make_atom(env, "moved");
        case SDL_WINDOWEVENT_RESIZED: return enif_make_atom(env, "resized");
        case SDL_WINDOWEVENT_SIZE_CHANGED: return enif_make_atom(env, "size_changed");
        case SDL_WINDOWEVENT_MINIMIZED: return enif_make_atom(env, "minimized");
        case SDL_WINDOWEVENT_MAXIMIZED: return enif_make_atom(env, "maximized");
        case SDL_WINDOWEVENT_RESTORED: return enif_make_atom(env, "restored");
        case SDL_WINDOWEVENT_ENTER: return enif_make_atom(env, "enter");
        case SDL_WINDOWEVENT_LEAVE: return enif_make_atom(env, "leave");
        case SDL_WINDOWEVENT_FOCUS_GAINED: return enif_make_atom(env, "focus_gained");
        case SDL_WINDOWEVENT_FOCUS_LOST: return enif_make_atom(env, "focus_lost");
        case SDL_WINDOWEVENT_CLOSE: return enif_make_atom(env, "close");
        default: return enif_make_atom(env, "unknown");
    }
}
#endif

/*
 * Helper: Translate SDL event to Elixir term
 * Returns translated event or :no_event
 */
#if DESKTOPUI_HAS_SDL2
static ERL_NIF_TERM translate_sdl_event(ErlNifEnv* env, SDL_Event* event)
{
    switch (event->type) {
        case SDL_QUIT: {
            return enif_make_atom(env, "quit");
        }

        case SDL_KEYDOWN: {
            ERL_NIF_TERM keycode = keycode_to_atom(env, event->key.keysym.sym);
            ERL_NIF_TERM modifiers = modifiers_to_map(env, event->key.keysym.mod);
            return enif_make_tuple3(env, enif_make_atom(env, "key_down"), keycode, modifiers);
        }

        case SDL_KEYUP: {
            ERL_NIF_TERM keycode = keycode_to_atom(env, event->key.keysym.sym);
            ERL_NIF_TERM modifiers = modifiers_to_map(env, event->key.keysym.mod);
            return enif_make_tuple3(env, enif_make_atom(env, "key_up"), keycode, modifiers);
        }

        case SDL_MOUSEBUTTONDOWN: {
            ERL_NIF_TERM button = button_to_atom(env, event->button.button);
            ERL_NIF_TERM x = enif_make_int(env, event->button.x);
            ERL_NIF_TERM y = enif_make_int(env, event->button.y);
            return enif_make_tuple4(env, enif_make_atom(env, "mouse_button_down"), button, x, y);
        }

        case SDL_MOUSEBUTTONUP: {
            ERL_NIF_TERM button = button_to_atom(env, event->button.button);
            ERL_NIF_TERM x = enif_make_int(env, event->button.x);
            ERL_NIF_TERM y = enif_make_int(env, event->button.y);
            return enif_make_tuple4(env, enif_make_atom(env, "mouse_button_up"), button, x, y);
        }

        case SDL_MOUSEMOTION: {
            ERL_NIF_TERM x = enif_make_int(env, event->motion.x);
            ERL_NIF_TERM y = enif_make_int(env, event->motion.y);
            ERL_NIF_TERM xrel = enif_make_int(env, event->motion.xrel);
            ERL_NIF_TERM yrel = enif_make_int(env, event->motion.yrel);
            return enif_make_tuple5(env, enif_make_atom(env, "mouse_motion"), x, y, xrel, yrel);
        }

        case SDL_WINDOWEVENT: {
            ERL_NIF_TERM window_event = window_event_to_atom(env, event->window.event);
            ERL_NIF_TERM data1 = enif_make_int(env, event->window.data1);
            ERL_NIF_TERM data2 = enif_make_int(env, event->window.data2);
            return enif_make_tuple4(env, enif_make_atom(env, "window_event"), window_event, data1, data2);
        }

        default: {
            // Return :unknown_event for unhandled event types
            return enif_make_tuple2(env, enif_make_atom(env, "unknown_event"),
                                  enif_make_int(env, event->type));
        }
    }
}
#endif

/*
 * nif_poll_event() -> event | :no_event | {:error, reason}
 *
 * Poll for SDL events without blocking.
 * Returns the next event from the queue, or :no_event if no events pending.
 *
 * Returns:
 *   - event tuple (e.g., {:quit}, {:key_down, ...}, etc.)
 *   - :no_event if no events pending
 *   - {:error, reason} on failure
 */
static ERL_NIF_TERM nif_poll_event(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
    (void)argv;  // May be unused if SDL2 not available at compile time
    desktop_ui_nif_state* state = (desktop_ui_nif_state*) enif_priv_data(env);

    if (argc != 0) {
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
    SDL_Event event;
    int result = SDL_PollEvent(&event);

    if (result == 0) {
        // No events pending
        return enif_make_atom(env, "no_event");
    } else if (result < 0) {
        // Error polling event
        set_last_error(state, SDL_GetError());
        ERL_NIF_TERM error_msg = enif_make_string(env, SDL_GetError(), ERL_NIF_UTF8);
        return enif_make_tuple2(env, enif_make_atom(env, "error"), error_msg);
    } else {
        // Event available - translate it
        return translate_sdl_event(env, &event);
    }
#endif
}

/*
 * nif_wait_event(timeout) -> event | :timeout | {:error, reason}
 *
 * Wait for SDL events with a timeout.
 * Blocks until an event is available or timeout expires.
 *
 * Parameters:
 *   - timeout: Timeout in milliseconds (integer)
 *
 * Returns:
 *   - event tuple (e.g., {:quit}, {:key_down, ...}, etc.)
 *   - :timeout if no events within timeout
 *   - {:error, reason} on failure
 */
static ERL_NIF_TERM nif_wait_event(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
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
    // Extract timeout (integer)
    int timeout;
    if (!enif_get_int(env, argv[0], &timeout)) {
        return enif_make_badarg(env);
    }

    // Validate timeout (non-negative)
    if (timeout < 0) {
        set_last_error(state, "Timeout must be non-negative");
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_string(env, "Timeout must be non-negative", ERL_NIF_UTF8));
    }

    SDL_Event event;
    int result = SDL_WaitEventTimeout(&event, timeout);

    if (result == 0) {
        // Timeout
        return enif_make_atom(env, "timeout");
    } else if (result < 0) {
        // Error waiting for event
        set_last_error(state, SDL_GetError());
        ERL_NIF_TERM error_msg = enif_make_string(env, SDL_GetError(), ERL_NIF_UTF8);
        return enif_make_tuple2(env, enif_make_atom(env, "error"), error_msg);
    } else {
        // Event available - translate it
        return translate_sdl_event(env, &event);
    }
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
    {"nif_present_render", 1, nif_present_render, 0},
    {"nif_poll_event", 0, nif_poll_event, 0},
    {"nif_wait_event", 1, nif_wait_event, 0}
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

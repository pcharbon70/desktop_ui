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

/*
 * ============================================================================
 * NIF State Management
 * ============================================================================
 */

typedef struct {
    int initialized;
    char last_error[512];
    char version[32];
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
    memset(state->last_error, 0, sizeof(state->last_error));
    strncpy(state->last_error, "No error", sizeof(state->last_error) - 1);
    memset(state->version, 0, sizeof(state->version));
    strncpy(state->version, "0.1.0-nif", sizeof(state->version) - 1);

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
        memcpy(new_state->last_error, old_state->last_error, sizeof(new_state->last_error));
        memcpy(new_state->version, old_state->version, sizeof(new_state->version));
    } else {
        new_state->initialized = 1;
        memset(new_state->last_error, 0, sizeof(new_state->last_error));
        strncpy(new_state->last_error, "No error", sizeof(new_state->last_error) - 1);
        memset(new_state->version, 0, sizeof(new_state->version));
        strncpy(new_state->version, "0.1.0-nif", sizeof(new_state->version) - 1);
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
    {"nif_is_initialized", 0, nif_is_initialized, 0}
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

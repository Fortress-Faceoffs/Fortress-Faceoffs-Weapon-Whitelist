#if defined __ffweplist_included_
    #endinput
#endif
#define __ffweplist_included_

/**
 * Loads a specified config.
 * @param configName    The name of the config
 */
native void FFWL_LoadConfig(char[] configName);

/**
 * Called when a user gets their loadout applied successfully.
 * @param client: The user that got their loadout applied.
 * @noreturn
 */
forward void FFWL_LoadoutApplied(int client);

/**
 * Called when the config is successfully loaded
 * @noparams
 * @noreturn
 */
forward void FFWL_ConfigLoaded();

public SharedPlugin __pl_ffweplist =
{
    name = "ffweplist",
    file = "ffweplist.smx",
    #if defined REQUIRE_PLUGIN
        required = 1,
    #else
        required = 0,
    #endif
}
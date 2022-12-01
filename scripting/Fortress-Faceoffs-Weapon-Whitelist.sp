#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include <tf2attributes>
#include <cfgmap>
#include <devstuff/utilstuff.sp>
#pragma newdecls required
#pragma semicolon 1


public Plugin myinfo =
{
	name = "Fortress-Faceoffs-Weapon-Whitelist",
	author = "minesettimi",
	description = "Enforces weapon whitelist by removing banned weapons and giving allowed weapons",
	version = "1.0.0",
	url = "https://github.com/Fortress-Faceoffs/Fortress-Faceoffs-Weapon-Whitelist"
};

ConVar enabled;
ConVar weaponConfig;
ConfigMap config;

bool loaded = false;
bool allowedClasses[9] = {false, ...};
TFClassType defaultClass;

public void OnPluginStart()
{

	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);

	enabled = CreateConVar("ffweplist_enabled", "0", "Enable ffdonk features.", _, true, 0.0, true, 1.0);
	enabled.AddChangeHook(OnEnabledChanged);

	weaponConfig = CreateConVar("ffweplist_file", "example.cfg", "Which config to use for the whitelist.");

	AutoExecConfig(true, "ffweplist");
}

void loadConfig()
{
	//Get and properly format config name
	char configLocation[64];
	char configName[32];

	weaponConfig.GetString(configName, sizeof(configName));

	Format(configLocation, sizeof(configLocation), "config/%s", configName);

	config = new ConfigMap(configLocation);

	if (!config)
	{
		PrintToServer("[FFWhitelist] Weapon config not found! Use ffweplist_file to set the config name.");
		return;
	}

	ConfigMap root = config.GetSection("config");

	if (!root)
	{
		PrintToServer("[FFWhitelist] Incorrect config found!");
		return;
	}

	//Get default class
	int defClass = 0;
	root.GetInt("default", defClass);

	if (defClass < 1 || defClass > 9)
	{
		PrintToServer("[FFWhitelist] Invalid default class in config!");
		return;
	}

	defaultClass = view_as<TFClassType>(defClass);

	// Prevent plugin from continuing if it can't find a class
	bool loadedClass = false;

	for (int i = 1; i <= 9; i++)
	{
		ConfigMap class = root.GetIntSection(i);
		
		if (!class) continue;

		if (!loadedClass) loadedClass = true;

		// Prevent loading if there are no valid weapons on class.

		bool hasValidSlot = false;
		for (int slot = 0; slot < 2; slot++)
		{
			ConfigMap slotConfig = class.GetIntSection(slot);
			
			if (!slotConfig) continue;

			if (slotConfig.GetSection("default") == null || slotConfig.GetSection("0") == null) continue;

			hasValidSlot = true;
		}

		if (!hasValidSlot)
		{
			PrintToServer("[FFWhitelist] Found class %i but no weapons are available!");
			continue;
		}

		allowedClasses[i-1] = true;
	}

	if (!loadedClass)
	{
		PrintToServer("[FFWhitelist] No classes found in config!");
		return;
	}
	
	if (!allowedClasses[defClass])
	{
		PrintToServer("[FFWhitelist] Default class isn't allowed!");
		return;
	}
	

	loaded = true;
}

public void OnEnabledChanged(ConVar convar, char[] oldvalue, char[] newvalue)
{
	if (StringToInt(newvalue) == 0)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (isPlayerReal(i))
			{
				TF2_RegeneratePlayer(i);
			}
		}

		PrintToServer("Weapon whitelist plugin is disabled.");
	}
	else
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (isPlayerReal(i))
			{
				TF2_RegeneratePlayer(i);
			}
		}

		PrintToServer("Weapon whitelist plugin is enabled.");
	}
}

public void Event_PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	if (enabled.BoolValue && event != INVALID_HANDLE)
	{
		int client = GetClientOfUserId(GetEventInt(event, "userid"));

		if (isPlayerReal(client))
		{
			CreateTimer(0.1, Timer_PlayerApplication, client);
		}
	}
}

public Action Timer_PlayerApplication(Handle timer, int client)
{
	
	return Plugin_Handled;
}

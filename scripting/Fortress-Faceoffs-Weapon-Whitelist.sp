#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include <tf2attributes>
#include <cfgmap>
#include <tf_econ_data>
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

char classes[][] = 
{
	"unknown",
	"scout",
	"sniper",
	"soldier",
	"demoman",
	"medic",
	"heavy",
	"pyro",
	"spy",
	"engineer"
};

char slotNames[][] =
{
	"primary",
	"secondary",
	"melee",
	"pda",
	"pda2",
	"building"
};

public void OnPluginStart()
{

	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);

	enabled = CreateConVar("ffweplist_enabled", "0", "Enable ffdonk features.", _, true, 0.0, true, 1.0);
	enabled.AddChangeHook(OnEnabledChanged);

	weaponConfig = CreateConVar("ffweplist_file", "example.cfg", "Which config to use for the whitelist.");

	RegAdminCmd("ffweplist_reloadconfig", ConCmd_Reload, ADMFLAG_BAN, "Reloads the weapon config.", "ffweplist");

	AutoExecConfig(true, "ffweplist");

	LoadConfig();
}

public Action ConCmd_Reload(int client, int args)
{
	LoadConfig();
	ReplyToCommand(client, "[FFWhitelist] Reloaded config.");
	return Plugin_Handled;
}

void LoadConfig()
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
	TFClassType defClass;
	char classBuffer[128];
	
	root.Get("default", classBuffer, sizeof(classBuffer));

	defClass = TF2_GetClass(classBuffer);

	if (defClass == TFClass_Unknown)
	{
		PrintToServer("[FFWhitelist] Invalid default class in config!");
		return;
	}


	// Prevent plugin from continuing if it can't find a class
	bool loadedClass = false;

	for (int i = 1; i < sizeof(classes); i++)
	{
		ConfigMap class = root.GetSection(classes[i]);
		
		if (!class) continue;

		if (!loadedClass) loadedClass = true;

		// Prevent loading if there are no valid weapons on class.

		bool hasValidSlot = false;
		for (int slot = 0; slot < sizeof(slotNames); slot++)
		{
			ConfigMap slotConfig = class.GetSection(slotNames[slot]);
			
			if (!slotConfig) continue;

			if (slotConfig.GetSection("default") == null || slotConfig.GetIntKeyValType(0) == KeyValType_Null) continue;
			
			//Cycle through weapons
			/* 
			for (int wep = 0; slotConfig.GetIntKeyValType(i) != KeyValType_Null; i++)
			{
				char wepName[64];
				slotConfig.GetIntKey(wep, wepName, sizeof(wepName));
				if (StrEqual(wepName,))
			} */

			hasValidSlot = true;
		}

		if (!hasValidSlot)
		{
			PrintToServer("[FFWhitelist] Found class: %s but no weapons are available!", classes[i]);
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
	
	PrintToServer("[FFWhitelist] Whitelist loaded and verified!");
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

		LoadConfig();
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
	if (!enabled.BoolValue || !loaded) return Plugin_Handled;

	//dont enforce weapons on spectators
	if (TF2_GetClientTeam(client) == TFTeam_Spectator || TF2_GetClientTeam(client) == TFTeam_Unassigned)
		return Plugin_Handled;
		
	//Class authentication
	int class = view_as<int>(TF2_GetPlayerClass(client));

	if (!allowedClasses[class-1])
	{
		TF2_SetPlayerClass(client, defaultClass);
		class = view_as<int>(defaultClass);
		TF2_RegeneratePlayer(client);
	}

	ConfigMap classConfig = config.GetSection(classes[class]);

	if (classConfig == null)
	{
		PrintToServer("[FFWhitelist] Unable to find class section for class: %s!", classes[class]);
		return Plugin_Handled;
	}

	for (int slot = 0; slot < sizeof(slotNames); slot++)
	{
		ConfigMap slotConfig = classConfig.GetSection(slotNames[slot]);
		
		//remove weapons when not defined
		if (slotConfig == null)
		{
			TF2_RemoveWeaponSlot(client, slot);
			continue;
		}

		int wepEnt = TF2Util_GetPlayerLoadoutEntity(client, slot);
		
		// just incase it doesn't get regular weapons
		if (wepEnt == -1)
		{
			continue;
		}
		
		// get info about current weapon
		int wepID = WeaponID(wepEnt);
		char wepClass[64];
		
		TF2Econ_GetItemClassName(wepID, wepClass, sizeof(wepClass));
		
		// check if current weapon is valid
		bool validWep = false;
		
		//keep iterating until it cant find a key
		for (int i = 0; slotConfig.GetIntKeyValType(i) != KeyValType_Null; i++)
		{
			int whitelistSize = slotConfig.GetIntKeySize(i);
			char[] whitelistItem = new char[whitelistSize];

			slotConfig.GetIntKey(i, whitelistItem, whitelistSize);
			
			// check to test the weapon class or id based on entry.
			if (StrContains(whitelistItem, "tf_", false) != -1)
			{
				if (StrEqual(whitelistItem, wepClass))
				{
					validWep = true;
					break;
				}
			}
			else
			{
				int whitelistId = StringToInt(whitelistItem);

				if (wepID == whitelistId)
				{
					validWep = true;
					break;
				}
			}
		}

		if (!validWep)
		{
			int defaultWep = -1;
			slotConfig.GetInt("default", defaultWep);
			char defaultWepClass[64];
			
			//Get classname and report it if its not there.
			if (!TF2Econ_GetItemClassName(defaultWep, defaultWepClass, sizeof(defaultWepClass)))
			{
				PrintToServer("[FFWhitelist] Invalid default weapon for slot: %i", slot);
				return Plugin_Handled;
			}
			
			//equip wearable if requested item is wearable
			bool isWearable = false;

			if (StrContains(defaultWepClass, "tf_wearable") != -1)
				isWearable = true;

			TF2_RemoveWeaponSlot(client, slot);
			CreateNamedItem(client, defaultWep, defaultWepClass, 15, 6, isWearable);
		}		
	}

	return Plugin_Handled;
}

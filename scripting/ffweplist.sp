#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#include <tf2>
#include <tf2_stocks>
#include <tf2attributes>

#include <cfgmap>

#include <tf_econ_data>
#include <stocksoop/tf/weapon>
#include <tf2utils>

#pragma newdecls required
#pragma semicolon 1

GlobalForward loadoutApplied;
GlobalForward configLoaded;

public Plugin myinfo =
{
	name = "Fortress-Faceoffs-Weapon-Whitelist",
	author = "minesettimi",
	description = "Enforces weapon whitelist by removing banned weapons and giving allowed weapons",
	version = "2.1.13",
	url = "https://github.com/Fortress-Faceoffs/Fortress-Faceoffs-Weapon-Whitelist"
};

ConVar enabled;
ConVar weaponConfig;
ConVar autoLoad;
ConfigMap config;

bool loaded = false;
bool allowedClasses[9] = {false, ...};
TFClassType defaultClass;
char configName[64] = "";

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

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("ffweplist");

	CreateNative("FFWL_LoadConfig", Native_LoadConfig);
	loadoutApplied = new GlobalForward("FFWL_LoadoutApplied", ET_Ignore, Param_Cell);
	configLoaded = new GlobalForward("FFWL_ConfigLoaded", ET_Ignore);

	return APLRes_Success;
}

public void OnPluginStart()
{
	//HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	HookEvent("post_inventory_application", Event_Regenerate, EventHookMode_Post);

	enabled = CreateConVar("ffweplist_enabled", "1", "When set, the plugin will be enabled.", _, true, 0.0, true, 1.0);
	enabled.AddChangeHook(OnEnabledChanged);

	autoLoad = CreateConVar("ffweplist_autoload", "1", "Autoloads the config.", _, true, 0.0, true, 1.0);

	weaponConfig = CreateConVar("ffweplist_file", "", "An override to which config that the plugin is using.");
	weaponConfig.AddChangeHook(FileChanged);

	RegAdminCmd("ffweplist_reloadconfig", ConCmd_Reload, ADMFLAG_BAN, "Reloads the weapon config.", "ffweplist");

	//AutoExecConfig(true, "ffweplist");

	if (autoLoad.BoolValue) CreateTimer(1.0, LoadTimer, 0, TIMER_FLAG_NO_MAPCHANGE);
}

void FileChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (autoLoad.BoolValue) CreateTimer(1.0, LoadTimer, 0, TIMER_FLAG_NO_MAPCHANGE);
}

public Action ConCmd_Reload(int client, int args)
{
	ReplyToCommand(client, "[FFWhitelist] Attempting to load config.");
	LoadConfig(configName);
	return Plugin_Handled;
}

Action LoadTimer(Handle timer)
{
	LoadConfig(configName);
	return Plugin_Handled;
}

void LoadConfig(char[] newConfig)
{
	if (!enabled.BoolValue) return;

	loaded = false;
	configName = "";

	//Get and properly format config name
	char configLocation[64];
	char overrideName[32];
	char newConfigBuffer[64] = "";

	StrCat(newConfigBuffer, sizeof(newConfigBuffer), newConfig);

	weaponConfig.GetString(overrideName, sizeof(overrideName));

	if (!StrEqual(overrideName, ""))
		newConfigBuffer = overrideName;

	Format(configLocation, sizeof(configLocation), "configs/ffwl/%s", newConfigBuffer);

	if (config != INVALID_HANDLE)
		delete config;

	config = new ConfigMap(configLocation);

	if (!config)
	{
		PrintToServer("[FFWhitelist] Weapon config failed to load! If not the correct name, use ffweplist_file to set the config name.");
		return;
	}

	ConfigMap root = config.GetSection("root");

	if (!root)
	{
		PrintToServer("[FFWhitelist] Incorrect config found!");
		return;
	}

	defaultClass = TFClass_Unknown;
	for (int i = 0; i < sizeof(allowedClasses); i++)
		allowedClasses[i] = false;

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

	defaultClass = defClass;

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

			if (slotConfig.GetKeyValType("default") == KeyValType_Null || slotConfig.GetKeyValType("0") == KeyValType_Null) continue;
			
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
	
	if (!allowedClasses[view_as<int>(defClass)-1])
	{
		PrintToServer("[FFWhitelist] Default class isn't whitelisted!");
		return;
	}

	//Forward success
	Call_StartForward(configLoaded);
	Call_Finish();
	
	PrintToServer("[FFWhitelist] Whitelist loaded and verified!");
	strcopy(configName, sizeof(configName), newConfigBuffer);
	loaded = true;
}

any Native_LoadConfig(Handle plugin, int numParams)
{
	int length;
	GetNativeStringLength(1, length);

	char[] buffer = new char[length];
	GetNativeString(1, buffer, length+1);

	LoadConfig(buffer);
	RegenAllPlayers();

	return true;
}

public void OnEnabledChanged(ConVar convar, char[] oldvalue, char[] newvalue)
{
	if (StringToInt(newvalue) == 0)
	{
		RegenAllPlayers();

		PrintToServer("Weapon whitelist plugin is disabled.");
	}
	else
	{
		LoadConfig(configName);
		RegenAllPlayers();

		PrintToServer("Weapon whitelist plugin is enabled.");
	}
}

public void RegenAllPlayers()
{
	for (int i = 1; i <= MaxClients; i++)
			if (IsClientConnected(i))
				TF2_RegeneratePlayer(i);
}

public Action Event_PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	if (enabled.BoolValue && event != INVALID_HANDLE)
	{
		int client = GetClientOfUserId(GetEventInt(event, "userid"));

		if (IsClientConnected(client))
			CreateTimer(0.1, Timer_PlayerApplication, client);
	}

	return Plugin_Handled;
}

public Action Event_Regenerate(Handle event, const char[] name, bool dontBroadcast)
{
	if (enabled.BoolValue && event != INVALID_HANDLE)
	{
		int client = GetClientOfUserId(GetEventInt(event, "userid"));
		if (IsClientConnected(client))
			CreateTimer(0.1, Timer_PlayerApplication, client);
	}

	return Plugin_Handled;
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
		TF2_RespawnPlayer(client);
		return Plugin_Handled;
	}

	ConfigMap root = config.GetSection("root");

	ConfigMap classConfig = root.GetSection(classes[class]);

	if (classConfig == null)
	{
		PrintToServer("[FFWhitelist] Unable to find class section for class: %s!", classes[class]);
		return Plugin_Handled;
	}

	int autoEquipSlot = -1;

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
		
		if (wepEnt == -1)
			continue;

		if (autoEquipSlot == -1) autoEquipSlot = slot;
		
		// get info about current weapon
		int wepID = WeaponID(client, wepEnt);
		char wepClass[64];

		TF2Econ_GetItemClassName(wepID, wepClass, sizeof(wepClass));
		
		// check if current weapon is valid
		bool validWep = false;
		
		//keep iterating until it cant find a key
		for (int key = 0; slotConfig.GetIntKeyValType(key) != KeyValType_Null; key++)
		{
			char whitelistItem[128];

			slotConfig.GetIntKey(key, whitelistItem, sizeof(whitelistItem));

			// check to test the weapon class or id based on entry.
			if (!IsCharNumeric(whitelistItem[0])) //weapon classnames should never have a number
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

		//If all of the previous checks couldn't find that the weapon in the currently active slot is valid, remove it and give them a whitelisted weapon
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

	if (autoEquipSlot != -1) SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", GetPlayerWeaponSlot(client, autoEquipSlot));

	//remove overheal
	int maxHealth = TF2Util_GetEntityMaxHealth(client);
	SetEntityHealth(client, maxHealth);

	//test fix
	TF2_RemoveCondition(client, TFCond_Kritzkrieged);

	//Forward loadout applied.
	Call_StartForward(loadoutApplied);
	Call_PushCell(client);
	Call_Finish();

	return Plugin_Handled;
}

int WeaponID(int client, int entity = -1, int slot = -1)
{
    if (entity == -1)
    {
        entity = GetPlayerWeaponSlot(client, slot);
    }

    if (!IsValidEntity(entity)) return -1;

    return GetEntProp(entity, Prop_Send, "m_iItemDefinitionIndex");
}

int CreateNamedItem(int client, int itemindex, const char[] classname, int level, int quality, bool wearable = false)
{
    int weapon = CreateEntityByName(classname);
    
    if (!IsValidEntity(weapon))
    {
        LogError("Invalid!");
        return -1;
    }
    
    char entclass[64];

    GetEntityNetClass(weapon, entclass, sizeof(entclass));	

    SetEntData(weapon, FindSendPropInfo(entclass, "m_iItemDefinitionIndex"), itemindex);
    SetEntData(weapon, FindSendPropInfo(entclass, "m_bInitialized"), 1);
    SetEntData(weapon, FindSendPropInfo(entclass, "m_iEntityLevel"), level);
    SetEntData(weapon, FindSendPropInfo(entclass, "m_iEntityQuality"), quality);

    SetEntProp(weapon, Prop_Send, "m_bValidatedAttachedEntity", 1);

    DispatchSpawn(weapon);

    if (!wearable) 
    {
		EquipPlayerWeapon(client, weapon);
		TF2_ResetWeaponAmmo(weapon);
	}
    else
        TF2Util_EquipPlayerWearable(client, weapon);
    
    return weapon;
}

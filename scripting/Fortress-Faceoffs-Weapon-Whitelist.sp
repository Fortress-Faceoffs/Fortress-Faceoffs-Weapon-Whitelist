#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include <tf2attributes>
#include <devstuff/utilstuff.sp>
#include <tf2utils>
#pragma newdecls required
#pragma semicolon 1


public Plugin myinfo =
{
	name = "Fortress-Faceoffs-Weapon-Whitelist",
	author = "minesettimi",
	description = "",
	version = "1.0.0",
	url = "https://github.com/minesettimi/Fortress-Faceoffs-Weapon-Whitelist"
};

ConVar enabled;

public void OnPluginStart()
{

	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);

	enabled = CreateConVar("ffdonk_enabled", "0", "Enable ffdonk features.", _, true, 0.0, true, 1.0);
	enabled.AddChangeHook(OnEnabledChanged);

	AutoExecConfig(true, "ffdonk");

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

		PrintToServer("Unloaded Weapon Whitelist");
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

		PrintToServer("Loaded Weapon Whitelist");
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
	if (!enabled.BoolValue) return Plugin_Handled;
	
	// Dont apply to non-players
	if (TF2_GetClientTeam(client) == TFTeam_Spectator || TF2_GetClientTeam(client) == TFTeam_Unassigned)
		return Plugin_Handled;
	
	//Enforce heavy class
	if (TF2_GetPlayerClass(client) != TFClass_Heavy)
	{
		TF2_SetPlayerClass(client, TFClass_Heavy, _, true);
		TF2_RespawnPlayer(client);
	}
	
	//No primary
	TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary);

	//Cant do classname as BSS is same classname as sandvich
	int secondID = WeaponID(client, _, 1);

	// Same for holiday punch 
	int meleeID = WeaponID(client, _, 2);
		
	//inefficient but only way to do this
	if (secondID != 42 && secondID != 159 && secondID != 433 && secondID != 863 && secondID != 1002)
	{
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);
		CreateNamedItem(client, 42, "tf_weapon_lunchbox", 15, 6);
	}

	if (meleeID != 656)
	{
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Melee);
		CreateNamedItem(client, 656, "tf_weapon_fists", 15, 6);
	}    

	return Plugin_Handled;
}

//Credit to TF2 MicroGames gamemode devs

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
	}
	else
	{
		TF2Util_EquipPlayerWearable(client, weapon);
	}
	
	return weapon;
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
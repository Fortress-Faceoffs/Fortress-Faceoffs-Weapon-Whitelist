#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include <tf2attributes>
#include <devstuff/utilstuff.sp>
#pragma newdecls required
#pragma semicolon 1


public Plugin myinfo =
{
	name = "Fortress-Faceoffs-Weapon-Whitelist",
	author = "minesettimi",
	description = "",
	version = "1.0.3",
	url = "https://github.com/minesettimi/Fortress-Faceoffs-Weapon-Whitelist"
};

ConVar enabled;

public void OnPluginStart()
{

	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	HookEvent("post_inventory_application", Event_Regenerate, EventHookMode_Post);

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

public Action Event_PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	if (enabled.BoolValue && event != INVALID_HANDLE)
	{
		int client = GetClientOfUserId(GetEventInt(event, "userid"));

		if (isPlayerReal(client))
			CreateTimer(0.1, Timer_PlayerApplication, client);
	}

	return Plugin_Handled;
}

public Action Event_Regenerate(Handle event, const char[] name, bool dontBroadcast)
{
	if (enabled.BoolValue && event != INVALID_HANDLE)
	{
		int client = GetClientOfUserId(GetEventInt(event, "userid"));
		if (isPlayerReal(client))
			CreateTimer(0.1, Timer_PlayerApplication, client);
	}

	return Plugin_Handled;
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
	if (secondID != 42 && secondID != 159 && secondID != 433 && secondID != 863 && secondID != 1002 && secondID != 1190)
	{
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);
		CreateNamedItem(client, 42, "tf_weapon_lunchbox", 15, 6);
	}

	if (meleeID != 656)
	{
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Melee);
		CreateNamedItem(client, 656, "tf_weapon_fists", 15, 6);
	}

	int playerWep = GetPlayerWeaponSlot(client, 2);

	FakeClientCommand(client, "use %i", playerWep);

	return Plugin_Handled;
}

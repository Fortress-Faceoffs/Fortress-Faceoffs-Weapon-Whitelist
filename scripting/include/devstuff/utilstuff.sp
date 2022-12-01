public bool isPlayerReal(client)
{
    bool isReal = true;

    if (client == 0 || !IsClientConnected(client) || IsFakeClient(client) || !IsClientInGame(client))
        isReal = false;

    return isReal;
}

public int CreateNamedItem(int client, int itemindex, const char[] classname, int level, int quality, bool wearable = false)
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

public int WeaponID(int client, int slot, int entity = -1)
{
    if (entity == -1)
    {
        entity = GetPlayerWeaponSlot(client, slot);
    }

    if (!IsValidEntity(entity)) return -1;

    return GetEntProp(entity, Prop_Send, "m_iItemDefinitionIndex");
}
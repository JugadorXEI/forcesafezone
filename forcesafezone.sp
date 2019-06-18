#include <sourcemod>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0"
#define MAX_ZONES 64

public Plugin myinfo = 
{
	name = "Force BR Safe Zone",
	author = "JugadorXEI",
	description = "When safe zone conditions are met, the selected safe zone will always be used.",
	version = PLUGIN_VERSION,
	url = "http://www.sourcemod.net/"
};

ConVar cvIsEnabled;

int g_iSafezoneArray[MAX_ZONES] = { -1, ... };
char g_cSafezoneNameArray[MAX_ZONES][64];

int g_iCurrentlyForcedSafeZone = -1;

bool g_bIsBREnabled = false;
bool g_bAreWeForcingZone = false;

public void OnPluginStart()
{
	HookEvent("teamplay_round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("teamplay_update_timer", Event_KOTHZone);

	cvIsEnabled = CreateConVar("sm_jb_debug_forcesafezone_enable", "1", "Should this plugin be enabled?", _, true, 0.0, true, 1.0);
	
	RegAdminCmd("sm_forcezone", ForceSafeZone, ADMFLAG_CHEATS, "Safe zone in BR to force (by number). Write /zonelist to get zones.");
	RegAdminCmd("sm_activatezone", Debug_ActivateZone, ADMFLAG_CHEATS, "Activates the effects of an specific zone, if available.");
	
	RegAdminCmd("sm_zonelist", ZoneList, ADMFLAG_CHEATS, "Gives all available zones to force.");
	RegAdminCmd("sm_zones", ZoneList, ADMFLAG_CHEATS, "Gives all available zones to force.");
}

public void OnMapStart()
{
	// We reset the value so the plugin doesn't crap out
	// when the map changes.
	g_iCurrentlyForcedSafeZone = -1;
	ResetListedZones();
	
	if (cvIsEnabled.BoolValue)
		PutZonesInList();
	
	char cConVarValue[64];
	GetConVarString(FindConVar("jb_sv_gamemode"), cConVarValue, sizeof(cConVarValue));
	
	g_bIsBREnabled = false;
	if (StrEqual("br", cConVarValue, false) || StrEqual("battleroyale", cConVarValue, false))
		g_bIsBREnabled = true;
}

public void Event_RoundStart(Event hEvent, const char[] cName, bool bDontBroadcast)
{
	// Because new entities can be added every round
	// we need to check safe zones every roundstart to make sure we've got everything.
	ResetListedZones();
	
	char cPreviousZoneName[64];
	
	if (g_iCurrentlyForcedSafeZone != -1)
		cPreviousZoneName = g_cSafezoneNameArray[g_iCurrentlyForcedSafeZone];
	
	// We'll get the zone entities.
	if (cvIsEnabled.BoolValue)
		PutZonesInList();
		
	// Here we match the previous zone with the one from the new round based on
	// their name. We do this because zones get readded every round.
	for (int i = 0; i < sizeof(g_cSafezoneNameArray); i++)
	{
		if (g_iSafezoneArray[i] == -1)
			break;
	
		if (StrEqual(g_cSafezoneNameArray[i], cPreviousZoneName))
		{
			g_iCurrentlyForcedSafeZone = i;
			break;
		}
	}

	g_bAreWeForcingZone = false;
}

public Action Event_KOTHZone(Event hEvent, const char[] cName, bool bDontBroadcast)
{	
	// We delete all other zones just so the one we want to force gets
	// triggered instead.
	if (!cvIsEnabled.BoolValue || g_iCurrentlyForcedSafeZone == -1)
		return Plugin_Continue;
	
	for(int i = 0; i < sizeof(g_iSafezoneArray); i++)
	{
		if (g_iSafezoneArray[i] == -1)
			break;
	
		if (i != g_iCurrentlyForcedSafeZone)
			AcceptEntityInput(g_iSafezoneArray[i], "Kill");
	}

	g_bAreWeForcingZone = true;

	//PrintToServer("Let's smoke a fat rip.");
	return Plugin_Continue;
}

public Action ForceSafeZone(int iClient, int iArgs)
{
	if (!CanPluginBeUsedRightNow(iClient))
		return Plugin_Handled;
	
	if (iArgs <= 0)
	{
		ReplyToCommand(iClient, "Usage: sm_forcezone [id] (current one is %i) (use sm_zonelist to get zone indexes).", g_iCurrentlyForcedSafeZone);
		return Plugin_Handled;
	}
	
	if (g_bAreWeForcingZone)
	{
		ReplyToCommand(iClient, "A zone cannot be forced while one is active.");
		return Plugin_Handled;
	}
	
	// If we got an ID.
	int iID = -1;
	char cParameter[3];
	
	GetCmdArg(1, cParameter, sizeof(cParameter));
	iID = StringToInt(cParameter);
	
	if (iID == -1 || iID > sizeof(g_iSafezoneArray))
	{
		ReplyToCommand(iClient, "You've set an invalid ID. Safe zones will not be forced.");
		g_iCurrentlyForcedSafeZone = -1;
		
		return Plugin_Handled;
	}
	
	g_iCurrentlyForcedSafeZone = iID;
	
	char cZoneName[64];
	GetEntPropString(g_iSafezoneArray[g_iCurrentlyForcedSafeZone], Prop_Data, "m_szMessage", cZoneName, sizeof(cZoneName));
	
	ReplyToCommand(iClient, "Next forced safe zone will be %i (%s).", g_iCurrentlyForcedSafeZone, cZoneName);

	return Plugin_Handled;
}

public Action ZoneList(int iClient, int iArgs)
{
	if (!CanPluginBeUsedRightNow(iClient))
		return Plugin_Handled;

	int iZonesListed = 0;
	for	(int i = 0; i < sizeof(g_iSafezoneArray); i++)
	{
		if (g_iSafezoneArray[i] == -1)
			break;
			
		char cZoneName[64];
		GetEntPropString(g_iSafezoneArray[i], Prop_Data, "m_szMessage", cZoneName, sizeof(cZoneName));
		
		char cMessage[128];
		Format(cMessage, sizeof(cMessage), "%i (%i) - %s", i, g_iSafezoneArray[i], g_cSafezoneNameArray[i]);
		PrintToConsole(iClient, cMessage);
		
		iZonesListed++;
	}
	
	if (iZonesListed > 0)
	{
		ReplyToCommand(iClient, "Check your console for zone indexes.");
	}
	else ReplyToCommand(iClient, "No zones have been found. " ...
	"(Datamap zones cannot be accessed due to logistical issues).");

	return Plugin_Handled;
}

public Action Debug_ActivateZone(int iClient, int iArgs)
{
	if (!CanPluginBeUsedRightNow(iClient))
		return Plugin_Handled;
	
	if (g_bAreWeForcingZone)
	{
		ReplyToCommand(iClient, "We cannot activate a zone while one is already active.");
		return Plugin_Handled;
	}
	
	if (iArgs <= 0)
	{
		ReplyToCommand(iClient, "Usage: sm_activatezone [id] (use sm_zonelist to get zone indexes).");
		return Plugin_Handled;
	}
	
	// If we got an ID.
	int iID = -1;
	char cParameter[3];
	
	GetCmdArg(1, cParameter, sizeof(cParameter));
	iID = StringToInt(cParameter);
	
	if (iID == -1 || iID > sizeof(g_iSafezoneArray))
	{
		ReplyToCommand(iClient, "You've set an invalid ID. No safe zone's effects will be triggered.");
		return Plugin_Handled;
	}
	
	FireEntityOutput(g_iSafezoneArray[iID], "OnSelected");
	
	ReplyToCommand(iClient, "%s (%i)'s effects have been activated.", g_cSafezoneNameArray[iID], iID);
	
	return Plugin_Handled;
}

public bool CanPluginBeUsedRightNow(int iClient)
{	
	if (!cvIsEnabled.BoolValue)
	{
		ReplyToCommand(iClient, "Force BR Safe Zone is disabled right now. Ask an admin to enable it.");
		return false;
	}
	
	if (!g_bIsBREnabled)
	{
		ReplyToCommand(iClient, "This plugin will not work correctly unless Battle Royale is being played.");
		return false;		
	}
	
	return true;
}

public void ResetListedZones()
{
	for	(int i = 0; i < sizeof(g_iSafezoneArray); i++)
	{
		if (g_iSafezoneArray[i] != -1)
		{
			g_iSafezoneArray[i] = -1;
			g_cSafezoneNameArray[i] = "No name";
		}
	}
}

public void PutZonesInList()
{
	int iEntity = -1;
	int iIndex = 0;
	
	while ((iEntity = FindEntityByClassname(iEntity, "jb_koth_zone")) != -1)
	{
		g_iSafezoneArray[iIndex] = iEntity;
		
		GetEntPropString(g_iSafezoneArray[iIndex], Prop_Data, "m_szMessage",
		g_cSafezoneNameArray[iIndex], sizeof(g_cSafezoneNameArray));
		
		//PrintToServer("Adding zone %i to zone list...", iEntity);
		iIndex++;
	}
}
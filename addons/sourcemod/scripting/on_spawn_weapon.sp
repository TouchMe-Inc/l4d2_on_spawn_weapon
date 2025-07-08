#pragma semicolon               1
#pragma newdecls                required


#include <sdktools>


public Plugin myinfo = {
	name = "OnSpawnWeapon",
	author = "TouchMe",
	description = "The plugin gives the player a weapon upon spawn",
	version = "build0001",
	url = "https://github.com/TouchMe-Inc/l4d2_on_spawn_weapon"
}


#define TEAM_SURVIVOR           2

#define PRIMARY_ANY             0
#define PRIMARY_ANY_TIER1       1
#define PRIMARY_ANY_TIER2       2
#define PRIMARY_CVAR            3

#define SECONDARY_ANY           0
#define SECONDARY_ANY_PISTOL    1
#define SECONDARY_ANY_MELEE     2
#define SECONDARY_CVAR          3


bool g_bRoundIsLive = false;

ConVar
	g_cvPrimaryWeapon = null, /*< sm_osw_primary */
	g_cvSecondaryWeapon = null; /*< sm_osw_secondary */

int
	g_iPrimaryWeapon = 0,
	g_iSecondaryWeapon = 0;

char g_sPrimaryWeapon[][] = {
	"smg_silenced", "smg", "smg_mp5",
	"pumpshotgun", "shotgun_chrome",
	"sniper_military", "hunting_rifle",
	"autoshotgun", "shotgun_spas",
	"rifle_ak47", "rifle_desert", "rifle_sg552", "rifle"
};

char g_sSecondaryWeapon[][] = {
	"pistol_magnum", "pistol",
	"baseball_bat", "cricket_bat",
	"crowbar", "electric_guitar",
	"fireaxe", "frying_pan",
	"golfclub", "katana",
	"knife", "machete",
	"pitchfork", "shovel",
	"tonfa"
};


/**
 * Called before OnPluginStart.
 *
 * @param myself      Handle to the plugin
 * @param bLate       Whether or not the plugin was loaded "late" (after map load)
 * @param sErr        Error message buffer in case load failed
 * @param iErrLen     Maximum number of characters for error message buffer
 * @return            APLRes_Success | APLRes_SilentFailure
 */
public APLRes AskPluginLoad2(Handle myself, bool bLate, char[] sErr, int iErrLen)
{
	EngineVersion engine = GetEngineVersion();

	if (engine != Engine_Left4Dead2)
	{
		strcopy(sErr, iErrLen, "Plugin only supports Left 4 Dead 2");
		return APLRes_SilentFailure;
	}

	return APLRes_Success;
}

/**
  * Called when the map loaded.
  */
public void OnMapStart() {
	g_bRoundIsLive = false;
}

public void OnPluginStart()
{
	// Cvars
	HookConVarChange((g_cvPrimaryWeapon = CreateConVar("sm_osw_primary_weapon", "any_tier1")), OnPrimaryWeaponChanged);
	HookConVarChange((g_cvSecondaryWeapon = CreateConVar("sm_osw_secondary_weapon", "any_pistol")), OnSecondaryWeaponChanged);

	// Events.
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_left_start_area", Event_LeftStartArea, EventHookMode_PostNoCopy);
	HookEvent("player_spawn", Event_PlayerSpawn);

	// Prepare vars.
	char sPrimaryWeapon[32];
	GetConVarString(g_cvPrimaryWeapon, sPrimaryWeapon, sizeof(sPrimaryWeapon));
	g_iPrimaryWeapon = ParsePrimaryWeapon(sPrimaryWeapon);

	char sSecondaryWeapon[32];
	GetConVarString(g_cvSecondaryWeapon, sSecondaryWeapon, sizeof(sSecondaryWeapon));
	g_iSecondaryWeapon = ParseSecondaryWeapon(sSecondaryWeapon);
}

/**
 * Called when a console variable value is changed.
 */
public void OnPrimaryWeaponChanged(ConVar convar, const char[] sOldWeapon, const char[] sNewWeapon) {
	g_iPrimaryWeapon = ParsePrimaryWeapon(sNewWeapon);
}

/**
 * Called when a console variable value is changed.
 */
public void OnSecondaryWeaponChanged(ConVar convar, const char[] sOldWeapon, const char[] sNewWeapon) {
	g_iSecondaryWeapon = ParseSecondaryWeapon(sNewWeapon);
}

void Event_RoundStart(Event event, const char[] sName, bool bDontBroadcast) {
	g_bRoundIsLive = false;
}

void Event_LeftStartArea(Event event, const char[] sName, bool bDontBroadcast) {
	g_bRoundIsLive = true;
}

Action Event_PlayerSpawn(Event event, const char[] sName, bool bDontBroadcast)
{
	if (g_bRoundIsLive) {
		return Plugin_Continue;
	}

	int iClient = GetClientOfUserId(GetEventInt(event, "userid"));

	if (!IsClientSurvivor(iClient)) {
		return Plugin_Continue;
	}

	switch(g_iPrimaryWeapon)
	{
		case PRIMARY_ANY: {
			GivePlayerItem(iClient, g_sPrimaryWeapon[GetRandomInt(0, sizeof(g_sPrimaryWeapon) - 1)]);
		}

		case PRIMARY_ANY_TIER1: {
			GivePlayerItem(iClient, g_sPrimaryWeapon[GetRandomInt(0, 4)]);
		}

		case PRIMARY_ANY_TIER2: {
			GivePlayerItem(iClient, g_sPrimaryWeapon[GetRandomInt(5, sizeof(g_sPrimaryWeapon) - 1)]);
		}

		case PRIMARY_CVAR: {
			char sPrimaryWeapon[32];
			GetConVarString(g_cvPrimaryWeapon, sPrimaryWeapon, sizeof(sPrimaryWeapon));
			GivePlayerItem(iClient, sPrimaryWeapon);
		}
	}

	int iEntSecondaryWeapon = GetPlayerWeaponSlot(iClient, 1);

	if (iEntSecondaryWeapon != -1) {
		RemovePlayerItem(iClient, iEntSecondaryWeapon);
	}

	switch(g_iSecondaryWeapon)
	{
		case SECONDARY_ANY: {
			GivePlayerItem(iClient, g_sSecondaryWeapon[GetRandomInt(0, sizeof(g_sSecondaryWeapon) - 1)]);
		}

		case SECONDARY_ANY_MELEE: {
			GivePlayerItem(iClient, g_sSecondaryWeapon[GetRandomInt(2, sizeof(g_sSecondaryWeapon) - 1)]);
		}

		case SECONDARY_ANY_PISTOL: {
			GivePlayerItem(iClient, g_sSecondaryWeapon[GetRandomInt(0, 1)]);
		}

		case SECONDARY_CVAR: {
			char sSecondaryWeapon[32];
			GetConVarString(g_cvSecondaryWeapon, sSecondaryWeapon, sizeof(sSecondaryWeapon));
			GivePlayerItem(iClient, sSecondaryWeapon);
		}
	}

	return Plugin_Continue;
}

int ParsePrimaryWeapon(const char[] sPrimaryWeapon)
{
	if (StrEqual(sPrimaryWeapon, "any_tier1", false)) {
		return PRIMARY_ANY_TIER1;
	}

	else if (StrEqual(sPrimaryWeapon, "any_tier2", false)) {
		return PRIMARY_ANY_TIER2;
	}

	else if (StrEqual(sPrimaryWeapon, "any", false)) {
		return PRIMARY_ANY;
	}

	return PRIMARY_CVAR;
}

int ParseSecondaryWeapon(const char[] sSecondaryWeapon)
{
	if (StrEqual(sSecondaryWeapon, "any_pistol", false)) {
		return SECONDARY_ANY_PISTOL;
	}

	else if (StrEqual(sSecondaryWeapon, "any_melee", false)) {
		return SECONDARY_ANY_MELEE;
	}

	else if (StrEqual(sSecondaryWeapon, "any", false)) {
		return SECONDARY_ANY;
	}

	return SECONDARY_CVAR;
}

/**
 * Survivor team player?
 */
bool IsClientSurvivor(int iClient) {
	return (GetClientTeam(iClient) == TEAM_SURVIVOR);
}

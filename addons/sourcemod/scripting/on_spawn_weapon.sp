#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <sdktools>


public Plugin myinfo = {
    name        = "OnSpawnWeapon",
    author      = "TouchMe",
    description = "The plugin gives the player a weapon upon spawn",
    version     = "build0001",
    url         = "https://github.com/TouchMe-Inc/l4d2_on_spawn_weapon"
}


#define TEAM_SURVIVOR           2

#define SLOT_PRIMARY            0
#define SLOT_SECONDARY          1
#define SLOT_THROWABLE          2
#define SLOT_MEDKIT             3
#define SLOT_MISC               4

#define MAXSIZE_SLOT            5
#define MAXSIZE_WEAPON_NAME     32

#define CMD_POOL_PUSH          "osw_pool_push"
#define CMD_POOL_CLEAR         "osw_pool_clear"


ConVar g_cvSurvivorLimit = null;

Handle g_hWeaponSlots = null;
Handle g_hWeaponPool[MAXSIZE_SLOT] = {null, ...};
Handle g_hRoundWeaponPool[MAXSIZE_SLOT] = {null, ...};


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
    if (GetEngineVersion() != Engine_Left4Dead2)
    {
        strcopy(sErr, iErrLen, "Plugin only supports Left 4 Dead 2");
        return APLRes_SilentFailure;
    }

    return APLRes_Success;
}

public void OnPluginStart()
{
    g_hWeaponSlots = CreateTrie();

    for (int i = 0; i < MAXSIZE_SLOT; i++)
    {
        g_hWeaponPool[i] = CreateArray(ByteCountToCells(32));
    }

    FillWeaponSlots(g_hWeaponSlots);

    g_cvSurvivorLimit = FindConVar("survivor_limit");

    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);

    RegServerCmd(CMD_POOL_PUSH, Cmd_PoolPush);
    RegServerCmd(CMD_POOL_CLEAR, Cmd_PoolClear);
}

void Event_RoundStart(Event event, const char[] szEventName, bool bDontBroadcast) {
    CreateTimer(1.0, Timer_CheckAllSpawned, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
}

/**
 * Callback triggered when all survivors have spawned.
 *
 * Shuffles the list of survivor clients and distributes randomized weapons from the round-specific weapon pool.
 * Each player receives a weapon for each defined inventory slot.
 */
Action Timer_CheckAllSpawned(Handle hTimer)
{
    int iSurvivorMaxCount = GetConVarInt(g_cvSurvivorLimit);
    if (iSurvivorMaxCount != GetSurvivorCount()) {
        return Plugin_Continue;
    }

    for (int iWeaponSlot = 0; iWeaponSlot < MAXSIZE_SLOT; iWeaponSlot++)
    {
        if (g_hRoundWeaponPool[iWeaponSlot] != null) {
            delete g_hRoundWeaponPool[iWeaponSlot];
        }

        g_hRoundWeaponPool[iWeaponSlot] = CloneArray(g_hWeaponPool[iWeaponSlot]);
    }

    int iSurvivors[MAXPLAYERS + 1];
    int iSurvivorCount = 0;

    for (int iClient = 1; iClient <= MaxClients; iClient++)
    {
        if (!IsClientInGame(iClient) || !IsClientSurvivor(iClient)) {
            continue;
        }

        iSurvivors[iSurvivorCount++] = iClient;
    }

    ShuffleArray(iSurvivors, iSurvivorCount);

    char szWeaponName[MAXSIZE_WEAPON_NAME];
    for (int iIdx = 0; iIdx < iSurvivorCount; iIdx++)
    {
        int iSurvivor = iSurvivors[iIdx];

        for (int iWeaponSlot = 0; iWeaponSlot < MAXSIZE_SLOT; iWeaponSlot++)
        {
            int iPoolSize = GetArraySize(g_hRoundWeaponPool[iWeaponSlot]);

            if (!iPoolSize) {
                continue;
            }

            int iWeaponEnt = GetPlayerWeaponSlot(iSurvivor, iWeaponSlot);

            if (iWeaponEnt != -1) {
                RemovePlayerItem(iSurvivor, iWeaponEnt);
            }

            int iWeaponIdx = GetRandomInt(0, iPoolSize - 1);
            GetArrayString(g_hRoundWeaponPool[iWeaponSlot], iWeaponIdx, szWeaponName, sizeof(szWeaponName));
            RemoveFromArray(g_hRoundWeaponPool[iWeaponSlot], iWeaponIdx);

            GivePlayerItem(iSurvivor, szWeaponName);
        }
    }

    return Plugin_Stop;
}

/**
 * Adds a weapon to its corresponding slot pool a specified number of times.
 * The weapon name must match an entry in the weapon slot trie.
 *
 * @param iArgs  Expected to be 2 arguments: <weapon> <count>
 * @return       Plugin_Handled
 */
public Action Cmd_PoolPush(int iArgs)
{
    if (iArgs != 2)
    {
        LogError("Invalid command \"%s\". Usage: \"%s <weapon> <value>\"", CMD_POOL_PUSH, CMD_POOL_PUSH);
        return Plugin_Handled;
    }

    char szWeaponName[MAXSIZE_WEAPON_NAME]; GetCmdArg(1, szWeaponName, sizeof(szWeaponName));

    int iWeaponSlot = -1;
    if (!GetTrieValue(g_hWeaponSlots, szWeaponName, iWeaponSlot))
    {
        LogError("Weapon \"%s\" not found", szWeaponName);
        return Plugin_Handled;
    }

    char szWeaponValue[4]; GetCmdArg(2, szWeaponValue, sizeof(szWeaponValue));
    int iWeaponCount = StringToInt(szWeaponValue);

    if (iWeaponCount <= 0)
    {
        LogError("Try push \"%s\" with incorrected value \"%d\"", szWeaponName, iWeaponCount);
        return Plugin_Handled;
    }

    for (int iRepeat = 0; iRepeat < iWeaponCount; iRepeat++)
    {
        PushArrayString(g_hWeaponPool[iWeaponSlot], szWeaponName);
    }

    return Plugin_Handled;
}

/**
 * Clears all weapon entries in every slot pool. Used to reset global weapon pools.
 *
 * @param iArgs  Number of arguments passed to the command (ignored)
 * @return       Plugin_Handled
 */
Action Cmd_PoolClear(int iArgs)
{
    for (int iWeaponSlot = 0; iWeaponSlot < MAXSIZE_SLOT; iWeaponSlot++)
    {
        ClearArray(g_hWeaponPool[iWeaponSlot]);
    }

    return Plugin_Handled;
}

/**
 * Populates the weapon slot trie with predefined weapon-to-slot mappings.
 *
 * Each weapon is mapped to its corresponding inventory slot:
 * - SLOT_PRIMARY: main guns like rifles, shotguns, and snipers
 * - SLOT_SECONDARY: pistols and melee weapons
 * - SLOT_THROWABLE: throwable items (pipe bombs, molotovs, bile)
 * - SLOT_MEDKIT: healing gear (medkits, defibs)
 * - SLOT_MISC: temporary boosts (pills, adrenaline)
 *
 * This mapping is used to categorize weapons during pool distribution.
 *
 * @param hWeaponSlot  The trie handle to fill with weapon-slot pairs
 */
void FillWeaponSlots(Handle hWeaponSlot)
{
    SetTrieValue(hWeaponSlot, "weapon_smg",              SLOT_PRIMARY);
    SetTrieValue(hWeaponSlot, "weapon_pumpshotgun",      SLOT_PRIMARY);
    SetTrieValue(hWeaponSlot, "weapon_autoshotgun",      SLOT_PRIMARY);
    SetTrieValue(hWeaponSlot, "weapon_rifle",            SLOT_PRIMARY);
    SetTrieValue(hWeaponSlot, "weapon_hunting_rifle",    SLOT_PRIMARY);
    SetTrieValue(hWeaponSlot, "weapon_smg_silenced",     SLOT_PRIMARY);
    SetTrieValue(hWeaponSlot, "weapon_shotgun_chrome",   SLOT_PRIMARY);
    SetTrieValue(hWeaponSlot, "weapon_rifle_desert",     SLOT_PRIMARY);
    SetTrieValue(hWeaponSlot, "weapon_sniper_military",  SLOT_PRIMARY);
    SetTrieValue(hWeaponSlot, "weapon_shotgun_spas",     SLOT_PRIMARY);
    SetTrieValue(hWeaponSlot, "weapon_grenade_launcher", SLOT_PRIMARY);
    SetTrieValue(hWeaponSlot, "weapon_rifle_ak47",       SLOT_PRIMARY);
    SetTrieValue(hWeaponSlot, "weapon_smg_mp5",          SLOT_PRIMARY);
    SetTrieValue(hWeaponSlot, "weapon_rifle_sg552",      SLOT_PRIMARY);
    SetTrieValue(hWeaponSlot, "weapon_sniper_awp",       SLOT_PRIMARY);
    SetTrieValue(hWeaponSlot, "weapon_sniper_scout",     SLOT_PRIMARY);
    SetTrieValue(hWeaponSlot, "weapon_rifle_m60",        SLOT_PRIMARY);
    SetTrieValue(hWeaponSlot, "weapon_melee",            SLOT_SECONDARY);
    SetTrieValue(hWeaponSlot, "weapon_chainsaw",         SLOT_SECONDARY);
    SetTrieValue(hWeaponSlot, "weapon_pistol",           SLOT_SECONDARY);
    SetTrieValue(hWeaponSlot, "weapon_pistol_magnum",    SLOT_SECONDARY);
    SetTrieValue(hWeaponSlot, "baseball_bat",            SLOT_SECONDARY);
    SetTrieValue(hWeaponSlot, "cricket_bat",             SLOT_SECONDARY);
    SetTrieValue(hWeaponSlot, "crowbar",                 SLOT_SECONDARY);
    SetTrieValue(hWeaponSlot, "electric_guitar",         SLOT_SECONDARY);
    SetTrieValue(hWeaponSlot, "fireaxe",                 SLOT_SECONDARY);
    SetTrieValue(hWeaponSlot, "frying_pan",              SLOT_SECONDARY);
    SetTrieValue(hWeaponSlot, "golfclub",                SLOT_SECONDARY);
    SetTrieValue(hWeaponSlot, "katana",                  SLOT_SECONDARY);
    SetTrieValue(hWeaponSlot, "knife",                   SLOT_SECONDARY);
    SetTrieValue(hWeaponSlot, "machete",                 SLOT_SECONDARY);
    SetTrieValue(hWeaponSlot, "pitchfork",               SLOT_SECONDARY);
    SetTrieValue(hWeaponSlot, "shovel",                  SLOT_SECONDARY);
    SetTrieValue(hWeaponSlot, "tonfa",                   SLOT_SECONDARY);
    SetTrieValue(hWeaponSlot, "weapon_pipe_bomb",        SLOT_THROWABLE);
    SetTrieValue(hWeaponSlot, "weapon_molotov",          SLOT_THROWABLE);
    SetTrieValue(hWeaponSlot, "weapon_vomitjar",         SLOT_THROWABLE);
    SetTrieValue(hWeaponSlot, "weapon_first_aid_kit",    SLOT_MEDKIT);
    SetTrieValue(hWeaponSlot, "weapon_defibrillator",    SLOT_MEDKIT);
    SetTrieValue(hWeaponSlot, "weapon_pain_pills",       SLOT_MISC);
    SetTrieValue(hWeaponSlot, "weapon_adrenaline",       SLOT_MISC);
}

/**
 * Checks whether the client belongs to the survivor team.
 *
 * @param iClient   Index of the client (1..MaxClients)
 * @return          true if the client is on TEAM_SURVIVOR; false otherwise
 */
bool IsClientSurvivor(int iClient) {
    return (GetClientTeam(iClient) == TEAM_SURVIVOR);
}

/**
 * Counts the number of survivor team members currently in-game.
 *
 * Iterates through all clients and returns how many are active and belong to TEAM_SURVIVOR.
 *
 * @return  Number of survivor clients currently in the game
 */
int GetSurvivorCount()
{
    int iSurvivorCount = 0;

    for (int iClient = 1; iClient <= MaxClients; iClient++)
    {
        if (!IsClientInGame(iClient) || !IsClientSurvivor(iClient)) {
            continue;
        }

        iSurvivorCount++;
    }

    return iSurvivorCount;
}

/**
 * Randomly shuffles the contents of an integer array in-place using Fisher-Yates algorithm.
 *
 * @param array     The array to shuffle (e.g. client indices)
 * @param count     Number of active elements in the array (not the array’s full size)
 */
void ShuffleArray(int[] array, int count)
{
    for (int i = count - 1; i > 0; i--)
    {
        int j = GetRandomInt(0, i);

        int temp = array[i];
        array[i] = array[j];
        array[j] = temp;
    }
}

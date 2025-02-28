#include <sourcemod>
#include <json>

public Plugin myinfo =
{
    name        = "Play To Earn",
    author      = "Gxsper",
    description = "Play to Earn for Team Fortress 2",
    version     = SOURCEMOD_VERSION,
    url         = "http://www.sourcemod.net/"
};

Database    walletsDB;

JSON_Object onlinePlayers;    // Stores online players datas `https://wiki.alliedmods.net/Generic_Source_Server_Events#player_connect`

char        winnerValue[20] = "1000000000000000000";    // 1 PTE
char        loserValue[20]  = "500000000000000000";     // 0.5 PTE
public void OnPluginStart()
{
    PrintToServer("[PTE] Play to Earn plugin has been initialized");

    char walletDBError[32];
    walletsDB = SQL_Connect("default", true, walletDBError, sizeof(walletDBError));
    if (walletsDB == null)
    {
        PrintToServer("[PTE] ERROR Connecting to the database: %s", walletDBError);
        PrintToServer("[PTE] The plugin will stop now...");
        return;
    }

    onlinePlayers = new JSON_Object();

    // Match Finish Event
    HookEvent("teamplay_win_panel", Event_RoundEnd, EventHookMode_PostNoCopy);

    // Player connected
    HookEvent("player_connect", OnPlayerConnect, EventHookMode_Post);

    // Player disconnected
    HookEventEx("player_disconnect", OnPlayerDisconnect, EventHookMode_Post);

    // Wallet command
    RegConsoleCmd("wallet", Command_Test, "Set up your Wallet address");
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    // 3 == blue
    // 2 == red
    int winningTeam = event.GetInt("winning_team");

    PrintToServer("[PTE] Calculating player incomings... the winner is: %d", winningTeam);

    int length     = onlinePlayers.Length;
    int key_length = 0;
    for (int i = 0; i < length; i += 1)
    {
        PrintToServer("----------------------------------");

        key_length = onlinePlayers.GetKeySize(i);
        char[] key = new char[key_length];
        onlinePlayers.GetKey(i, key, key_length);

        JSON_Object playerObj  = onlinePlayers.GetObject(key);

        int         index      = GetClientOfUserId(playerObj.GetInt("userId"));
        int         clientTeam = GetClientTeam(index);
        char        playerNetwork[32];
        playerObj.GetString("networkId", playerNetwork, 32);

        PrintToServer("Index: %d", index);
        PrintToServer("Network Id: %s", playerNetwork);
        PrintToServer("Player ID: %s", key);
        PrintToServer("Team: %d", clientTeam);
        PrintToServer("Winner: %d", winningTeam == clientTeam);

        if (winningTeam == clientTeam)
        {
            IncrementWallet(playerNetwork, winnerValue);
        }
        else {
            IncrementWallet(playerNetwork, loserValue);
        }
        PrintToServer("----------------------------------");
    }

    PrintToServer("Round Ended!");

    return Plugin_Continue;
}

public Action Command_Test(int client, int args)
{
    PrintToChat(client, "You can set your wallet in your discord: discord.com/...");

    return Plugin_Handled;
}

public void OnPlayerConnect(Event event, const char[] name, bool dontBroadcast)
{
    char playerName[64];
    char networkId[32];
    char address[32];
    int  index  = event.GetInt("index");
    int  userId = event.GetInt("userid");
    bool isBot  = event.GetBool("bot");

    event.GetString("name", playerName, sizeof(playerName));
    event.GetString("networkid", networkId, sizeof(networkId));
    event.GetString("address", address, sizeof(address));

    if (!isBot)
    {
        JSON_Object playerObj = new JSON_Object();
        playerObj.SetString("playerName", playerName);
        playerObj.SetString("networkId", networkId);
        playerObj.SetString("address", address);
        playerObj.SetInt("userId", userId);
        playerObj.SetInt("index", index);

        char userIdStr[8];
        IntToString(userId, userIdStr, sizeof(userIdStr));
        onlinePlayers.SetObject(userIdStr, playerObj);

        PrintToServer("[PTE] Player Connected: Name: %s | ID: %d | SteamID: %s | IP: %s | Bot: %d",
                      playerName, userId, networkId, address, isBot);
    }
}

public void OnPlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
    char playerName[64];
    char networkId[32];
    char reason[128];
    // int  index  = event.GetInt("index");
    int  userId = event.GetInt("userid");
    bool isBot  = event.GetBool("bot");

    event.GetString("name", playerName, sizeof(playerName));
    event.GetString("networkid", networkId, sizeof(networkId));
    event.GetString("reason", reason, sizeof(reason));

    if (!isBot)
    {
        int length     = onlinePlayers.Length;
        int key_length = 0;
        for (int i = 0; i < length; i += 1)
        {
            key_length = onlinePlayers.GetKeySize(i);
            char[] key = new char[key_length];
            onlinePlayers.GetKey(i, key, key_length);

            JSON_Object playerObj = onlinePlayers.GetObject(key);

            char        playerObjNetwork[32];
            playerObj.GetString("networkId", playerObjNetwork, 32);
            if (StrEqual(playerObjNetwork, networkId))
            {
                json_cleanup_and_delete(playerObj);

                char userIdStr[8];
                IntToString(userId, userIdStr, sizeof(userIdStr));
                onlinePlayers.Remove(userIdStr);
            }
        }

        PrintToServer("[PTE] Player Disconnected: Name: %s | ID: %d | SteamID: %s | Reason: %s | Bot: %d",
                      playerName, userId, networkId, reason, isBot);
    }
}

void IncrementWallet(char[] playerNetwork, char[] valueToIncrement)
{
    if (walletsDB == null)
    {
        PrintToServer("[PTE] ERROR: database is not connected");
        return;
    }

    // Checking player existance in database
    // Formatar a query SQL para verificar se o uniqueid já existe
    char checkQuery[512];
    Format(checkQuery, sizeof(checkQuery),
           "SELECT COUNT(*) FROM tf2 WHERE uniqueid = '%s';",
           playerNetwork);

    // Executar a query para verificar a existência do uniqueid
    DBResultSet hQuery = SQL_Query(walletsDB, checkQuery);
    if (hQuery == null)
    {
        char error[255];
        SQL_GetError(walletsDB, error, sizeof(error));
        PrintToServer("[PTE] Error checking if %s exists: %s", playerNetwork, error);
        return;
    }
    else {
        bool finded = false;
        while (SQL_FetchRow(hQuery))
        {
            int index = SQL_FetchInt(hQuery, 0);
            if (index == 0)
            {
                PrintToServer("[PTE] Address \"%s\" not found.", playerNetwork);
                return
            }
            else if (index > 1) {
                PrintToServer("[PTE] ERROR: Address \"%s\" is on multiples rows, you setup the database wrongly, please check it. rows: %d", playerNetwork, index);
                return;
            }
            else {
                PrintToServer("[PTE] Address \"%s\" was found in index. %d", playerNetwork, index);
            }

            break;
        }
        if (!finded)
        {
            PrintToServer("[PTE] Address \"%s\" not found.", playerNetwork);
            return;
        }
    }

    // Updating player in database
    char query[512];
    Format(query, sizeof(query),
           "UPDATE tf2 SET value = value + %s WHERE uniqueid = '%s';",
           valueToIncrement, playerNetwork);

    // Executar a query
    if (!SQL_FastQuery(walletsDB, query))
    {
        char error[255];
        SQL_GetError(walletsDB, error, sizeof(error));
        PrintToServer("[PTE] Cannot increment %s values", playerNetwork);
        PrintToServer(error);
    }
    else
    {
        PrintToServer("[PTE] Incremented %s value: %s", playerNetwork, valueToIncrement);
    }
}
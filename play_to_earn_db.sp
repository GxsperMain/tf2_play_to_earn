#include <sourcemod>
#include <json>
#include <tf2_stocks.inc>
#include <regex.inc>

public Plugin myinfo =
{
    name        = "Play To Earn",
    author      = "Gxsper",
    description = "Play to Earn for Team Fortress 2",
    version     = SOURCEMOD_VERSION,
    url         = "https://github.com/GxsperMain/tf2_play_to_earn"
};

Database    walletsDB;

JSON_Object onlinePlayers;                                                                                                  // Stores online players datas `https://wiki.alliedmods.net/Generic_Source_Server_Events#player_connect`
int         currentTimestamp             = 0;                                                                               // Stores a simple timestamp that goes upper every second
int         timestampIncomes[15]         = { 60, 120, 180, 240, 300, 360, 420, 480, 540, 600, 660, 720, 780, 840, 900 };    // Stores the timestamps to earn PTE's
const int   timestampIncomesSize         = 15;                                                                              // Must be the same as timeStampIncomes

char        timestampValue[15][20]       = { "100000000000000000", "200000000000000000", "300000000000000000",
                                "400000000000000000", "500000000000000000", "600000000000000000",
                                "700000000000000000", "800000000000000000", "900000000000000000",
                                "1000000000000000000", "1100000000000000000", "1200000000000000000",
                                "1300000000000000000", "1400000000000000000", "1500000000000000000" };    // The values to player receive based on timestampIncomes
char        timestampValueToShow[15][10] = { "0.1", "0.2", "0.3",
                                      "0.4", "0.5", "0.6",
                                      "0.7", "0.8", "0.9",
                                      "1.0", "1.1", "1.2",
                                      "1.3", "1.4", "1.5" };    // The values to player receive based on timestampIncomes
char        winnerValue[20]              = "500000000000000000";       // 0.5 PTE
char        loserValue[20]               = "300000000000000000";       // 0.3 PTE
bool        alertPlayerIncomings         = true;                       // Alert or not in the player chat if he received any incoming
const int   minimumTimePlayedForIncoming = 120;
const int   minimumPlayerForSoloMVP      = 16;
const int   minimumPlayerForTwoMVP       = 8;
const int   minimumPlayerForThreeMVP     = 4;
char        soloMVPValue[20]             = "100000000000000000";    // 1 PTE
char        twoMVPValue[20]              = "50000000000000000";     // 0.5 PTE
char        threeMVPValue[20]            = "30000000000000000";     // 0.3 PTE
char        soloMVPValueShow[10]         = "1.0";
char        twoMVPValueShow[10]          = "0.5";
char        threeMVPValueShow[10]        = "0.3";
const int   minimumScoreToReceiveMVP     = 5;

public void OnPluginStart()
{
    PrintToServer("[PTE] Play to Earn plugin has been initialized");
    CreateTimer(1.0, TimestampUpdate, _, TIMER_REPEAT);

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
    HookEvent("teamplay_win_panel", OnRoundEnd, EventHookMode_PostNoCopy);

    // Player connected
    HookEvent("player_connect", OnPlayerConnect, EventHookMode_Post);

    // Player disconnected
    HookEventEx("player_disconnect", OnPlayerDisconnect, EventHookMode_Post);

    // Wallet command
    RegConsoleCmd("wallet", CommandRegisterWallet, "Set up your Wallet address");

    // Player team changed
    HookEventEx("player_team", OnPlayerChangeTeam, EventHookMode_Post);

    // Round started
    HookEventEx("teamplay_round_start", OnRoundStart, EventHookMode_Post);

    // Player Warning
    CreateTimer(300.0, WarnPlayersWithoutWallet, _, TIMER_REPEAT);
}

//
// EVENTS
//
public void OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    // 3 == blue
    // 2 == red
    int winningTeam = event.GetInt("winning_team");

    PrintToServer("[PTE] Calculating player incomings... the winner is: %d", winningTeam);

    // Stores players ids that will be checked
    ArrayList scoresToCheckIds = new ArrayList();

    int       length           = onlinePlayers.Length;
    int       key_length       = 0;
    for (int i = 0; i < length; i += 1)
    {
        PrintToServer("----------------------------------");

        // Getting player data
        key_length = onlinePlayers.GetKeySize(i);
        char[] key = new char[key_length];
        onlinePlayers.GetKey(i, key, key_length);

        JSON_Object playerObj  = onlinePlayers.GetObject(key);

        int         index      = GetClientOfUserId(playerObj.GetInt("userId"));
        int         clientTeam = GetClientTeam(index);

        playerObj.SetInt("score", TF2_GetPlayerResourceData(index, TFResource_TotalScore));

        if (clientTeam != 2 && clientTeam != 3)
        {
            PrintToServer("Wrong Team");
            PrintToServer("----------------------------------");
            continue;
        }
        char playerNetwork[32];
        playerObj.GetString("networkId", playerNetwork, 32);

        // Getting PTE earned by playtime
        int  timePlayed                  = currentTimestamp - playerObj.GetInt("teamTimestamp", 0);
        int  timestampIndex              = -1;
        char timestampCurrentEarning[20] = "0";
        for (int j = 0; j < timestampIncomesSize; j++)
        {
            if (timePlayed >= timestampIncomes[j])
            {
                timestampIndex = j;
            }
            else {
                break;
            }
        }
        if (timestampIndex > -1)
        {
            timestampCurrentEarning = timestampValue[timestampIndex];
        }

        if (timePlayed < minimumTimePlayedForIncoming)
        {
            PrintToServer("Not enough playtime: %d", timePlayed);
            PrintToServer("----------------------------------");
            continue;
        }

        PrintToServer("Index: %d", index);
        PrintToServer("Network Id: %s", playerNetwork);
        PrintToServer("Player ID: %s", key);
        PrintToServer("Team: %d", clientTeam);
        PrintToServer("Winner: %d", winningTeam == clientTeam);
        PrintToServer("TimePlayed: %d", timePlayed);

        if (winningTeam == clientTeam)
        {
            IncrementWallet(playerNetwork, winnerValue, index, "0.5 PTE", ", for Winning");
        }
        else {
            IncrementWallet(playerNetwork, loserValue, index, "0.3 PTE", ", for Losing");
        }

        if (!StrEqual(timestampCurrentEarning, "0"))
        {
            char outputText[32];
            Format(outputText, sizeof(outputText), "%s PTE", timestampValueToShow[timestampIndex]);
            IncrementWallet(playerNetwork, timestampValue[timestampIndex], index, outputText, ", for Playing");
        }

        playerObj.SetInt("teamTimestamp", currentTimestamp);
        onlinePlayers.SetObject(key, playerObj);

        scoresToCheckIds.PushString(key);

        PrintToServer("----------------------------------");
    }

    PrintToServer("[PTE] Calculating player MVP");
    PrintToServer("############################");
    if (onlinePlayers.Length >= minimumPlayerForSoloMVP)
    {
        PrintToServer("Solo MVP");
        int  redSoloScore = -1;
        char redSoloNetworkId[32];
        int  redToRemove   = -1;
        int  redClient     = -1;

        int  blueSoloScore = -1;
        char blueSoloNetworkId[32];
        int  blueToRemove = -1;
        int  blueClient   = -1;

        for (int i = 0; i < scoresToCheckIds.Length; i++)
        {
            char playerId[32];
            scoresToCheckIds.GetString(i, playerId, sizeof(playerId));

            JSON_Object playerObj = onlinePlayers.GetObject(playerId);

            int         score     = playerObj.GetInt("score");
            int         team      = playerObj.GetInt("team");
            if (team == 2)
            {
                if (redSoloScore < score)
                {
                    redSoloScore     = score;
                    redSoloNetworkId = "";
                    playerObj.GetString("networkId", redSoloNetworkId, sizeof(redSoloNetworkId));
                    redToRemove = i;
                    redClient   = GetClientOfUserId(playerObj.GetInt("userId"));
                }
            }
            else if (team == 3)
            {
                if (blueSoloScore < score)
                {
                    blueSoloScore     = score;
                    blueSoloNetworkId = "";
                    playerObj.GetString("networkId", blueSoloNetworkId, sizeof(blueSoloNetworkId));
                    blueToRemove = i;
                    blueClient   = GetClientOfUserId(playerObj.GetInt("userId"));
                }
            }

            // Imprimindo o valor
            PrintToServer("Score %d: %d", i, score);
        }

        if (redSoloScore >= minimumScoreToReceiveMVP)
        {
            scoresToCheckIds.Erase(redToRemove);
            char outputText[32];
            Format(outputText, sizeof(outputText), "%s PTE", soloMVPValueShow);
            IncrementWallet(redSoloNetworkId, soloMVPValue, redClient, outputText, ", by Performance");
        }
        if (blueSoloScore >= minimumScoreToReceiveMVP)
        {
            scoresToCheckIds.Erase(blueToRemove);
            char outputText[32];
            Format(outputText, sizeof(outputText), "%s PTE", soloMVPValueShow);
            IncrementWallet(blueSoloNetworkId, soloMVPValue, blueClient, outputText, ", by Performance");
        }
    }
    if (onlinePlayers.Length >= minimumPlayerForTwoMVP)
    {
        PrintToServer("Two MVP");
        int  redTwoScore = -1;
        char redTwoNetworkId[32];
        int  redToRemove  = -1;
        int  redClient    = -1;

        int  blueTwoScore = -1;
        char blueTwoNetworkId[32];
        int  blueToRemove = -1;
        int  blueClient   = -1;

        for (int i = 0; i < scoresToCheckIds.Length; i++)
        {
            char playerId[32];
            scoresToCheckIds.GetString(i, playerId, sizeof(playerId));

            JSON_Object playerObj = onlinePlayers.GetObject(playerId);

            int         score     = playerObj.GetInt("score");
            int         team      = playerObj.GetInt("team");
            if (team == 2)
            {
                if (redTwoScore < score)
                {
                    redTwoScore     = score;
                    redTwoNetworkId = "";
                    playerObj.GetString("networkId", redTwoNetworkId, sizeof(redTwoNetworkId));
                    redToRemove = i;
                    redClient   = GetClientOfUserId(playerObj.GetInt("userId"));
                }
            }
            else if (team == 3)
            {
                if (blueTwoScore < score)
                {
                    blueTwoScore     = score;
                    blueTwoNetworkId = "";
                    playerObj.GetString("networkId", blueTwoNetworkId, sizeof(blueTwoNetworkId));
                    blueToRemove = i;
                    blueClient   = GetClientOfUserId(playerObj.GetInt("userId"));
                }
            }

            // Imprimindo o valor
            PrintToServer("Score %d: %d", i, score);
        }

        if (redTwoScore >= minimumScoreToReceiveMVP)
        {
            scoresToCheckIds.Erase(redToRemove);
            char outputText[32];
            Format(outputText, sizeof(outputText), "%s PTE", twoMVPValueShow);
            IncrementWallet(redTwoNetworkId, twoMVPValue, redClient, outputText, ", by Performance");
        }
        if (blueTwoScore >= minimumScoreToReceiveMVP)
        {
            scoresToCheckIds.Erase(blueToRemove);
            char outputText[32];
            Format(outputText, sizeof(outputText), "%s PTE", twoMVPValueShow);
            IncrementWallet(blueTwoNetworkId, twoMVPValue, blueClient, outputText, ", by Performance");
        }
    }
    if (onlinePlayers.Length >= minimumPlayerForThreeMVP)
    {
        PrintToServer("Three MVP");
        int  redThreeScore = -1;
        char redThreeNetworkId[32];
        int  redToRemove    = -1;
        int  redClient      = -1;

        int  blueThreeScore = -1;
        char blueThreeNetworkId[32];
        int  blueToRemove = -1;
        int  blueClient   = -1;

        for (int i = 0; i < scoresToCheckIds.Length; i++)
        {
            char playerId[32];
            scoresToCheckIds.GetString(i, playerId, sizeof(playerId));

            JSON_Object playerObj = onlinePlayers.GetObject(playerId);

            int         score     = playerObj.GetInt("score");
            int         team      = playerObj.GetInt("team");
            if (team == 2)
            {
                if (redThreeScore < score)
                {
                    redThreeScore     = score;
                    redThreeNetworkId = "";
                    playerObj.GetString("networkId", redThreeNetworkId, sizeof(redThreeNetworkId));
                    redToRemove = i;
                    redClient   = GetClientOfUserId(playerObj.GetInt("userId"));
                }
            }
            else if (team == 3)
            {
                if (blueThreeScore < score)
                {
                    blueThreeScore     = score;
                    blueThreeNetworkId = "";
                    playerObj.GetString("networkId", blueThreeNetworkId, sizeof(blueThreeNetworkId));
                    blueToRemove = i;
                    blueClient   = GetClientOfUserId(playerObj.GetInt("userId"));
                }
            }

            // Imprimindo o valor
            PrintToServer("Score %d: %d", i, score);
        }

        if (redThreeScore >= minimumScoreToReceiveMVP)
        {
            scoresToCheckIds.Erase(redToRemove);
            char outputText[32];
            Format(outputText, sizeof(outputText), "%s PTE", threeMVPValueShow);
            IncrementWallet(redThreeNetworkId, threeMVPValue, redClient, outputText, ", by Performance");
        }
        if (blueThreeScore >= minimumScoreToReceiveMVP)
        {
            scoresToCheckIds.Erase(blueToRemove);
            char outputText[32];
            Format(outputText, sizeof(outputText), "%s PTE", threeMVPValueShow);
            IncrementWallet(blueThreeNetworkId, threeMVPValue, blueClient, outputText, ", by Performance");
        }
    }
    PrintToServer("############################");

    PrintToServer("[PTE] Round Ended");
    ClearTemporaryData();
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

        char checkQuery[512];
        Format(checkQuery, sizeof(checkQuery),
               "SELECT COUNT(*) FROM tf2 WHERE uniqueid = '%s';",
               networkId);

        // Checking the player uniqueid existance
        DBResultSet hQuery = SQL_Query(walletsDB, checkQuery);
        if (hQuery == null)
        {
            char error[255];
            SQL_GetError(walletsDB, error, sizeof(error));
            PrintToServer("[PTE] Error checking if %s exists: %s", networkId, error);
            return;
        }
        else {
            while (SQL_FetchRow(hQuery))
            {
                int rows = SQL_FetchInt(hQuery, 0);
                if (rows == 0)
                {
                    onlinePlayers.SetBool("walletSet", false);
                    onlinePlayers.SetObject(userIdStr, playerObj);
                    PrintToServer("[PTE] %s does not have a wallet...", playerName);
                    return
                }
                else if (rows > 1) {
                    onlinePlayers.SetBool("walletSet", false);
                    PrintToServer("[PTE] ERROR: Address \"%s\" is on multiples rows, you setup the database wrongly, please check it. rows: %d", networkId, rows);
                    return;
                }
                else {
                    onlinePlayers.SetBool("walletSet", true);
                    PrintToServer("[PTE] %s have a wallet", playerName);
                    break;
                }
            }
        }

        PrintToServer("[PTE] Player Connected: Name: %s | ID: %d | Index: %d | SteamID: %s | IP: %s | Bot: %d",
                      playerName, userId, index, networkId, address, isBot);
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
                char userIdStr[8];
                IntToString(userId, userIdStr, sizeof(userIdStr));
                onlinePlayers.Remove(userIdStr);
                json_cleanup_and_delete(playerObj);
            }
        }

        PrintToServer("[PTE] Player Disconnected: Name: %s | ID: %d | SteamID: %s | Reason: %s | Bot: %d",
                      playerName, userId, networkId, reason, isBot);
    }
}

public void OnPlayerChangeTeam(Event event, const char[] name, bool dontBroadcast)
{
    bool disconnected = event.GetBool("disconnect");
    if (disconnected) return;

    int  userId  = event.GetInt("userid");
    int  team    = event.GetInt("team");
    int  oldTeam = event.GetInt("oldteam");

    char userIdStr[8];
    IntToString(userId, userIdStr, sizeof(userIdStr));

    // Probably a bot
    if (!JsonContains(onlinePlayers, userIdStr))
        return;

    JSON_Object playerObj = onlinePlayers.GetObject(userIdStr);

    char        playerName[32];
    playerObj.GetString("playerName", playerName, sizeof(playerName));

    PrintToServer("[PTE] %s changed their team: %d, previously: %d, timestamp: %d", playerName, team, oldTeam, playerObj.GetInt("teamTimestamp", 0));

    playerObj.SetInt("team", team);
    playerObj.SetInt("teamTimestamp", currentTimestamp);

    onlinePlayers.SetObject(userIdStr, playerObj);
}

public void OnMapEnd()
{
    PrintToServer("[PTE] Map ended");
    ClearTemporaryData();
}

public void OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
    PrintToServer("[PTE] Round started");
    ClearTemporaryData();
}
//
//
//

//
// Commands
//
public Action CommandRegisterWallet(int client, int args)
{
    if (args < 1)
    {
        PrintToChat(client, "You can set your wallet in your discord: discord.gg/3SYP9TRVuX");
        PrintToChat(client, "Or you can setup using !wallet 0x123...");
        return Plugin_Handled;
    }
    char walletAddress[256];
    GetCmdArgString(walletAddress, sizeof(walletAddress));

    if (ValidAddress(walletAddress))
    {
        char indexStr[32];
        IntToString(GetClientUserId(client), indexStr, sizeof(indexStr));

        JSON_Object playerObj = onlinePlayers.GetObject(indexStr);

        char        playerNetwork[32];
        playerObj.GetString("networkId", playerNetwork, sizeof(playerNetwork));

        // Updating player in database
        char query[512];
        Format(query, sizeof(query),
               "UPDATE tf2 SET walletaddress = '%s' WHERE uniqueid = '%s';",
               walletAddress, playerNetwork);

        // Running the update method
        if (!SQL_Query(walletsDB, query))
        {
            char error[255];
            SQL_GetError(walletsDB, error, sizeof(error));
            PrintToServer("[PTE] Cannot update %s wallet", playerNetwork);
            PrintToServer(error);
            PrintToChat(client, "Any error occurs when setting up your wallet, contact the server owner");
        }
        else
        {
            int affectedRows = SQL_GetAffectedRows(walletsDB);
            if (affectedRows == 0)
            {
                // Updating player in database
                char query2[512];
                Format(query2, sizeof(query2),
                       "INSERT INTO tf2 (uniqueid, walletaddress) VALUES ('%s', '%s');",
                       playerNetwork, walletAddress);

                // Running the update method
                if (!SQL_Query(walletsDB, query2))
                {
                    char error[255];
                    SQL_GetError(walletsDB, error, sizeof(error));
                    PrintToServer("[PTE] Cannot update %s wallet", playerNetwork);
                    PrintToServer(error);
                    PrintToChat(client, "Any error occurs when setting up your wallet, contact the server owner");
                }
                else
                {
                    int affectedRows2 = SQL_GetAffectedRows(walletsDB);
                    if (affectedRows2 == 0)
                    {
                        PrintToChat(client, "Any error occurs when setting up your wallet, contact the server owner");
                        PrintToServer("[PTE] No rows updated for %s wallet. The uniqueid might not exist.", playerNetwork);
                    }
                    else
                    {
                        PrintToChat(client, "Wallet set! you may now receive PTE while playing, have fun");
                        PrintToServer("[PTE] Updated %s wallet to: %s", playerNetwork, walletAddress);
                        playerObj.SetBool("walletSet", true);
                        onlinePlayers.SetObject(indexStr, playerObj);
                    }
                }
            }
            else
            {
                PrintToChat(client, "Wallet updated!");
                PrintToServer("[PTE] Updated %s wallet to: %s", playerNetwork, walletAddress);
            }
        }
    }
    else {
        PrintToChat(client, "The wallet address provided is invalid, if you need help you can ask in your discord: discord.gg/3SYP9TRVuX");
    }

    return Plugin_Handled;
}

//
//
//

//
// Utils
//
public Action TimestampUpdate(Handle timer)
{
    currentTimestamp++;
    return Plugin_Continue;
}

public Action WarnPlayersWithoutWallet(Handle timer)
{
    int length     = onlinePlayers.Length;
    int key_length = 0;
    for (int i = 0; i < length; i += 1)
    {
        key_length = onlinePlayers.GetKeySize(i);
        char[] key = new char[key_length];
        onlinePlayers.GetKey(i, key, key_length);

        JSON_Object playerObj = onlinePlayers.GetObject(key);
        if (!playerObj.GetBool("walletSet"))
        {
            int index = GetClientOfUserId(playerObj.GetInt("userId"));
            PrintToChat(index, "[PTE] You do not have a wallet set yet, find out more on our discord: discord.gg/3SYP9TRVuX");
        }
    }
    return Plugin_Continue;
}

void IncrementWallet(
    char[] playerNetwork,
    char[] valueToIncrement,
    int client         = -1,
    char[] valueToShow = "0 PTE",
    char[] reason      = ", for Playing")
{
    if (walletsDB == null)
    {
        PrintToServer("[PTE] ERROR: database is not connected");
        return;
    }

    // Checking player existance in database
    char checkQuery[512];
    Format(checkQuery, sizeof(checkQuery),
           "SELECT COUNT(*) FROM tf2 WHERE uniqueid = '%s';",
           playerNetwork);

    // Checking the player uniqueid existance
    DBResultSet hQuery = SQL_Query(walletsDB, checkQuery);
    if (hQuery == null)
    {
        char error[255];
        SQL_GetError(walletsDB, error, sizeof(error));
        PrintToServer("[PTE] Error checking if %s exists: %s", playerNetwork, error);
        return;
    }
    else {
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
                break;
            }
        }
    }

    // Updating player in database
    char query[512];
    Format(query, sizeof(query),
           "UPDATE tf2 SET value = value + %s WHERE uniqueid = '%s';",
           valueToIncrement, playerNetwork);

    // Running the update method
    if (!SQL_FastQuery(walletsDB, query))
    {
        char error[255];
        SQL_GetError(walletsDB, error, sizeof(error));
        PrintToServer("[PTE] Cannot increment %s values", playerNetwork);
        PrintToServer(error);
    }
    else
    {
        if (alertPlayerIncomings)
            PrintToChat(client, "[PTE] You received: %s%s", valueToShow, reason);
        PrintToServer("[PTE] Incremented %s value: %s, reason: '%s'", playerNetwork, valueToIncrement, reason);
    }
}

bool JsonContains(JSON_Object obj, const char[] keyToCheck)
{
    int length     = obj.Length;
    int key_length = 0;
    for (int i = 0; i < length; i += 1)
    {
        key_length = obj.GetKeySize(i);
        char[] key = new char[key_length];
        obj.GetKey(i, key, key_length);

        if (StrEqual(keyToCheck, key))
        {
            return true;
        }
    }
    return false;
}

void ClearTemporaryData()
{
    currentTimestamp = 0;

    int length       = onlinePlayers.Length;
    int key_length   = 0;
    for (int i = 0; i < length; i += 1)
    {
        key_length = onlinePlayers.GetKeySize(i);
        char[] key = new char[key_length];
        onlinePlayers.GetKey(i, key, key_length);

        JSON_Object playerObj = onlinePlayers.GetObject(key);
        if (playerObj == null) continue;
        playerObj.SetInt("teamTimestamp", currentTimestamp);
        playerObj.SetInt("score", 0);

        onlinePlayers.SetObject(key, playerObj);
    }
}

bool ValidAddress(const char[] address)
{
    char       error[128];
    RegexError errcode;
    Regex      regex = CompileRegex("^[a-zA-Z0-9]{42}$");

    if (errcode != REGEX_ERROR_NONE)
    {
        PrintToServer("[PTE] Wrong regex typed: %s", error);
        return false;
    }

    int result = regex.Match(address);
    return result > 0;
}
//
//
//

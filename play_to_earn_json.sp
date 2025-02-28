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

JSON_Object playerWallets;    // JSON: { NetworkID: Wallet }
JSON_Object wallets;          // JSON: { Wallet: PTE Quantity }

JSON_Object onlinePlayers;    // Stores online players datas `https://wiki.alliedmods.net/Generic_Source_Server_Events#player_connect`

float       winnerValue = 1.0;
float       loserValue  = 0.5;

public void OnPluginStart()
{
    PrintToServer("[PTE] Play to Earn plugin has been initialized");

    char playerWalletsString[16384];
    char walletsString[16384];

    onlinePlayers = new JSON_Object();

    // wallets.json Load
    CreateDirectory("wallets", 511);
    if (!FileExists("wallets/wallets.json"))
    {
        Handle walletsFile = OpenFile("wallets/wallets.json", "w");
        PrintToServer("wallets.json does not exist, creating one...");
        WriteFileString(walletsFile, "{}", false);
        strcopy(walletsString, sizeof(walletsString), "{}");
        CloseHandle(walletsFile);
    }
    else {
        Handle walletsFile = OpenFile("wallets/wallets.json", "r");
        ReadFileString(walletsFile, walletsString, sizeof(walletsString));
        CloseHandle(walletsFile);
    }

    // player_wallets.json Load
    CreateDirectory("wallets", 511);
    if (!FileExists("wallets/player_wallets.json"))
    {
        Handle playerWalletsFile = OpenFile("wallets/player_wallets.json", "w");
        PrintToServer("player_wallets.json does not exist, creating one...");
        WriteFileString(playerWalletsFile, "{}", false);
        strcopy(playerWalletsString, sizeof(playerWalletsString), "{}");
        CloseHandle(playerWalletsFile);
    }
    else {
        Handle playerWalletsFile = OpenFile("wallets/player_wallets.json", "r");
        ReadFileString(playerWalletsFile, playerWalletsString, sizeof(playerWalletsString));
        CloseHandle(playerWalletsFile);

        // Debug
        PrintToServer("player wallets:");
        PrintToServer(playerWalletsString);
    }

    playerWallets = json_decode(playerWalletsString);
    wallets       = json_decode(walletsString);

    // Match Finish Event
    HookEvent("teamplay_win_panel", Event_RoundEnd, EventHookMode_PostNoCopy);

    // Player connected
    HookEvent("player_connect", OnPlayerConnect, EventHookMode_Post);

    // Player disconnected
    HookEventEx("player_disconnect", OnPlayerDisconnect, EventHookMode_Post);

    // Wallet command
    RegConsoleCmd("wallet", Command_Test, "Set up your Wallet address");

    // Wallets update system
    CreateTimer(60.0, OnMinutePassed, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    // 3 == blue
    // 2 == red
    int winningTeam = event.GetInt("winning_team");

    PrintToServer("[PTE] Calculating player incomings...");

    int length     = onlinePlayers.Length;
    int key_length = 0;
    for (int i = 0; i < length; i += 1)
    {
        PrintToServer("----------------------------------");

        key_length = onlinePlayers.GetKeySize(i);
        char[] key = new char[key_length];
        onlinePlayers.GetKey(i, key, key_length);

        JSON_Object playerObj = onlinePlayers.GetObject(key);

        // Debug #0
        PrintToServer("Player ID: ");
        PrintToServer(key);

        int  index = GetClientOfUserId(playerObj.GetInt("userId"));

        // Debug #1
        char indexStr[8];
        IntToString(index, indexStr, 8);
        PrintToServer("Index: ");
        PrintToServer(indexStr);

        int  clientTeam = GetClientTeam(index);

        // Debug #2
        char clientTeamStr[8];
        IntToString(clientTeam, clientTeamStr, 8);
        PrintToServer("Team: ");
        PrintToServer(clientTeamStr);

        char playerNetwork[32];
        playerObj.GetString("networkId", playerNetwork, 32);

        // Debug #3
        PrintToServer("Network Id: ");
        PrintToServer(playerNetwork);

        if (winningTeam == clientTeam)
        {
            PrintToServer("Winner");

            IncrementWallet(playerNetwork, winnerValue);
        }
        else {
            PrintToServer("Loser");

            IncrementWallet(playerNetwork, loserValue);
        }
        PrintToServer("----------------------------------");
    }

    PrintToServer("Round Ended!");

    SaveWalletsValues();

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
    }

    PrintToServer("[PTE] Player Connected: Name: %s | ID: %d | SteamID: %s | IP: %s | Bot: %d",
                  playerName, userId, networkId, address, isBot);
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
    }

    PrintToServer("[PTE] Player Disconnected: Name: %s | ID: %d | SteamID: %s | Reason: %s | Bot: %d",
                  playerName, userId, networkId, reason, isBot);
}

public Action OnMinutePassed(Handle timer)    // Resync wallets
{
    // Player Wallets resync...
    if (FileExists("wallets/player_wallets.json") && FileExists("wallets/player_wallets.resync"))
    {
        char playerWalletsString[14000];
        json_cleanup_and_delete(wallets);

        Handle playerWalletsFile = OpenFile("wallets/player_wallets.json", "r");
        PrintToServer("[PTE] player_wallets.resync was called, replacing memory with player_wallets.json...");
        ReadFileString(playerWalletsFile, playerWalletsString, sizeof(playerWalletsString));
        CloseHandle(playerWalletsFile);

        playerWallets = json_decode(playerWalletsString);
    }
    else if (FileExists("wallets/player_wallets.resync")) {
        char playerWalletsString[14000];
        json_cleanup_and_delete(wallets);

        Handle playerWalletsFile = OpenFile("wallets/player_wallets.json", "w");
        PrintToServer("[PTE] player_wallets.resync was called, resetting player_wallets.json...");
        WriteFileString(playerWalletsFile, "{}", false);
        strcopy(playerWalletsString, sizeof(playerWalletsString), "{}");
        CloseHandle(playerWalletsFile);

        playerWallets = json_decode(playerWalletsString);
    }


    // Wallets resync...
    if (FileExists("wallets/wallets.lock"))
    {
        PrintToServer("[PTE] Wallets is locked, ignoring resync check...");
        return Plugin_Continue;
    }

    if (FileExists("wallets/wallets.json") && FileExists("wallets/wallets.resync"))
    {
        char walletsString[14000];
        json_cleanup_and_delete(wallets);

        Handle walletsFile = OpenFile("wallets/wallets.json", "r");
        PrintToServer("[PTE] wallets.resync was called, replacing memory with wallets.json...");
        ReadFileString(walletsFile, walletsString, sizeof(walletsString));
        CloseHandle(walletsFile);

        wallets = json_decode(walletsString);
    }
    else if (FileExists("wallets/wallets.resync")) {
        char walletsString[14000];
        json_cleanup_and_delete(wallets);

        Handle walletsFile = OpenFile("wallets/wallets.json", "w");
        PrintToServer("[PTE] wallets.resync was called, resetting wallets.json...");
        WriteFileString(walletsFile, "{}", false);
        strcopy(walletsString, sizeof(walletsString), "{}");
        CloseHandle(walletsFile);

        wallets = json_decode(walletsString);
    }

    return Plugin_Continue;
}

//
// Utils
//
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
void IncrementWallet(char[] playerNetwork, float valueToIncrement)
{
    if (JsonContains(playerWallets, playerNetwork))
    {
        PrintToServer("Contains a wallet");
        char walletAddress[43];
        playerWallets.GetString(playerNetwork, walletAddress, 43);

        if (JsonContains(wallets, walletAddress))
        {
            float actualValue = wallets.GetFloat(walletAddress);
            actualValue += valueToIncrement;
            wallets.SetFloat(walletAddress, actualValue);
        }
        else {
            wallets.SetFloat(playerNetwork, valueToIncrement);
        }
    }
    else {
        PrintToServer("Does not have a wallet");
    }
}
Action RepeatSaveWalletValues(Handle timer)    // For the timers repeat
{
    SaveWalletsValues();
    return Plugin_Continue;
}
void SaveWalletsValues()
{
    if (FileExists("wallets/wallets.lock"))
    {
        PrintToServer("[PTE] Wallets is locked, will repeat soon...");
        CreateTimer(10.0, RepeatSaveWalletValues, _);
        return;
    }
    if (FileExists("wallets/wallets.resync"))
    {
        PrintToServer("[PTE] Wallets is resyncing, will repeat soon...");
        CreateTimer(10.0, RepeatSaveWalletValues, _);
        return;
    }

    Handle walletsLock = OpenFile("wallets/wallets.lock", "w");
    CloseHandle(walletsLock);

    Handle walletsFile = OpenFile("wallets/wallets.json", "w");
    PrintToServer("[PTE] Save function was called, saving it...");

    char walletsString[14000];
    json_encode(wallets, walletsString, sizeof(walletsString));
    WriteFileString(walletsFile, walletsString, false);
    CloseHandle(walletsFile);

    DeleteFile("wallets/wallets.lock");
}
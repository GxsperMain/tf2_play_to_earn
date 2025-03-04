# Team Fortress 2 Play To Earn
Base template for running a server with play to earn support

## Functionality
- When the round ends the winning side will earn 0.5 PTE, the losing side will earn 0.3 PTE
- When the round ends player will earn PTE based on time play, maximum 1.5 at 15 minutes
- Players will only receive if at least played during 1 minute of playtime
- MVP players will receive 1 PTE coins
- SVP players will receive 0.5 PTE coins
- TVP players will receive 0.3 PTE coins
- Setup wallet as command ``!wallet 0x123...``

## Configuring
To configure you will need to manually change some values inside the file before compiling

``Database Version``
```cpp
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
```

``JSON Version``
```cpp
float       winnerValue = 1.0; // Value that players will earn when round end (winners)
float       loserValue  = 0.5; // Value that players will earn when round end (losers)
```

## Using Database
- Download Team Fortress 2 server files
- Install [sourcemod](https://www.sourcemod.net/downloads.php) and [metamod](https://www.sourcemm.net/downloads.php/?branch=stable)
- Install [sm_json](https://github.com/clugg/sm-json) for [sourcemod](https://www.sourcemod.net/downloads.php), just place the addons folder inside TeamFortress2/tf
- Install a database like mysql or mariadb
- Create a user for the database: GRANT ALL PRIVILEGES ON pte_wallets.* TO 'pte_admin'@'localhost' IDENTIFIED BY 'supersecretpassword' WITH GRANT OPTION; FLUSH PRIVILEGES;
- Create a table named ``tf2``:
```sql
CREATE TABLE tf2 (
    uniqueid VARCHAR(255) NOT NULL PRIMARY KEY,
    walletaddress VARCHAR(255) NOT NULL,
    value DECIMAL(50, 0) NOT NULL DEFAULT 0
);
```
- Copy the play_to_earn_db.sp inside TeamFortress2/tf/addons/sourcemod/scripting
- Inside the TeamFortress2/tf/addons/sourcemod/scripting should be a file to compile, compile it giving the play_to_earn_db.sp as parameter
- The file should be in TeamFortress2/tf/addons/sourcemod/scripting/compiled folder, copy the file compiled and place it in TeamFortress2/tf/addons/sourcemod/plugins folder
- Now you need to configure your database, go to TeamFortress2/tf/addons/sourcemod/databases.cfg, and add the database credentials
- Run the server normally, players should register their wallets using the steam ``steamID3:``, like: ``[U:1:0000000000]`` in the tf2 database

## Using JSON (not recommended)
- Download Team Fortress 2 server files
- Install [sourcemod](https://www.sourcemod.net/downloads.php) and [metamod](https://www.sourcemm.net/downloads.php/?branch=stable)
- Install [sm_json](https://github.com/clugg/sm-json) for [sourcemod](https://www.sourcemod.net/downloads.php), just place the addons folder inside TeamFortress2/tf
- Copy the play_to_earn_db.sp inside TeamFortress2/tf/addons/sourcemod/scripting
- Inside the TeamFortress2/tf/addons/sourcemod/scripting should be a file to compile, compile it giving the play_to_earn_db.sp as parameter
- The file should be in TeamFortress2/tf/addons/sourcemod/scripting/compiled folder, copy the file compiled and place it in TeamFortress2/tf/addons/sourcemod/plugins folder
- Run the server normally, players should register their wallets using the steam ``steamID3:``, like: ``[U:1:0000000000]``, the player wallets is located inside TeamFortress2/tf/wallets/player_wallets.json
```json
{
    "[U:1:0000000000]": "0x123..."
}
```

## Recommendations
- [block_team_switch.sp]() this plugin will block player from changing team, so you can prevent them for becoming afk in the team selector and select a team when the match is finishing.
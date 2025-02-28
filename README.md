# Team Fortress 2 Pay To Earn
Base template for running a server with play to earn support

## Functionality
- When the round ends the winning side will earn 1 PTE, the losing side will earn 0.5 PTE

## Configuring
To configure you will need to manually change some values inside the file

``Database Version``
```cpp
char        winnerValue[20] = "1000000000000000000";    // Value that players will earn when round end (winners) 1 PTE
char        loserValue[20]  = "500000000000000000";     // Value that players will earn when round end (losers) 0.5 PTE
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

# Using JSON (not recommended) and no supported
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
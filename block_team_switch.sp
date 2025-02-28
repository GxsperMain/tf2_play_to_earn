#pragma semicolon 1

#include <sourcemod>

/// Add this commands to the tf/cfg/server.cfg
/// mp_forceautoteam 1
/// mp_allowspectators 0

/// from: https://forums.alliedmods.net/showthread.php?t=172052
public Plugin:myinfo =
{
	name = "Block Teamswitch",
	author = "Tylerst",
	description = "Blocks Teamswitching",
	version = SOURCEMOD_VERSION,
	url = "https://github.com/GxsperMain/tf2_play_to_earn"
}

public OnPluginStart() AddCommandListener(Command_JoinTeam, "jointeam");
public Action:Command_JoinTeam(client, const String:command[], args) return Plugin_Handled;

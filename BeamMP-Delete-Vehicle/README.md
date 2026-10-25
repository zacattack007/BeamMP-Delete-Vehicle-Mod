# BeamMP-Delete-Vehicle-Mod
lets you remove any vehicles that are placed in an annoying spot or you justwant to teach someone a lesson for being annoying.
Only the configured BeamMP username may use this mod, regardless of their player ID.

**INSTALATION**

1. download the zip file
2. extract the files and put whats in the server folder in the [your-server-name]/resources/server folder

**CONFIGURATION**

Set `ALLOWED_USERNAME` at the top of `Server/Main.lua` to your exact BeamMP username, for example `local ALLOWED_USERNAME = "YourUsername"`. Matching ignores letter case. Leaving it empty disables access for everyone. Restart the plugin/server after changing it.

**COMMANDS**

`/dv <player_id|username> [vehicle_id]`

- `/dv 2` deletes all vehicles belonging to connected player ID 2.
- `/dv Zacat` deletes all vehicles belonging to the username Zacat.
- `/dv 2 0` or `/dv Zacat 0` deletes only that player's vehicle ID 0.
- `/dv "Player Name" 0` supports usernames containing spaces.
- `/dv "123"` targets the username 123; `/dv 123` targets player ID 123.

Usernames match the full connected name, ignoring letter case. Partial names and ambiguous matches are rejected. Player IDs are the current server session IDs, not BeamMP account IDs. Invalid vehicle IDs are rejected without deleting anything. Only the configured username may use these commands; player ID 0 has no special access.
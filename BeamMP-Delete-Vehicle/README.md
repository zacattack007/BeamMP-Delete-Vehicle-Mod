# BeamMP-Delete-Vehicle-Mod
lets you remove any vehicles that are placed in an annoying spot or you justwant to teach someone a lesson for being annoying.
Only the configured BeamMP username may use this mod, regardless of their player ID.

**INSTALATION**

1. download the zip file
2. extract the files and put whats in the server folder in the [your-server-name]/resources/server folder

**CONFIGURATION**

Set `ALLOWED_USERNAME` at the top of `Server/Main.lua` to your exact BeamMP username, for example `local ALLOWED_USERNAME = "YourUsername"`. Matching ignores letter case. Leaving it empty disables access for everyone. Restart the plugin/server after changing it.

**COMMANDS**

`/help` shows this mod's commands and examples privately in chat. Anyone can view help; `/dv` remains restricted to the configured username.

`/dv <player_id|username> [vehicle_id]`

- `/dv list Zacat` or `/dv list 2` lists that player's vehicle IDs in order, showing the internal model name, configuration filename when available, and a delete command for each. Listing does not delete anything.
- `/dv list "Player Name"` supports names with spaces. Use `/dv "list"` to target a player whose username is literally list.
- `/dv 2` deletes all vehicles belonging to connected player ID 2.
- `/dv Zacat` deletes all vehicles belonging to the username Zacat.
- `/dv 2 0` or `/dv Zacat 0` deletes only that player's vehicle ID 0.
- `/dv "Player Name" 0` supports usernames containing spaces.
- `/dv "123"` targets the username 123; `/dv 123` targets player ID 123.

Usernames match the full connected name, ignoring letter case. Partial names and ambiguous matches are rejected. Player IDs are the current server session IDs, not BeamMP account IDs. Invalid vehicle IDs are rejected without deleting anything. Only the configured username may use these commands; player ID 0 has no special access.
Example list entry: `Vehicle ID 0 - pickup (config: base) - delete with: /dv 2 0`. Model names are internal BeamNG names, including mod models. Missing or unreadable vehicle details show `Unknown model`; IDs remain available.

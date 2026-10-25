# BeamMP Delete Vehicle Mod

A server-side mod for finding and deleting players' vehicles. The server owner can grant access to multiple admins and manage those permissions in chat.

## Installation

1. Use BeamMP Server 3.1.0 or newer.
2. Create `Resources/Server/BeamMP-Delete-Vehicle` inside your server folder.
3. Copy `Server/Main.lua` from this download into that folder.
4. Configure the owner username below, then start or restart the server.

## Owner configuration

The public version ships with no owner configured. Set this line near the top of `Main.lua` to the owner's registered BeamMP username:

```lua
local ALLOWED_USERNAME = "YourUsername"
```

Matching ignores letter case. An empty username disables all `/dv` commands, even for saved admins. `/dvhelp` remains available to everyone. Guest accounts cannot receive admin permissions. Player ID 0 has no special access.

The owner always has access and is the only person who can add, remove, list, or reset admins. Added admins can list and delete vehicles, but cannot manage permissions. Change the owner by editing this configuration, not through chat.

## Permissions

| Command | Result |
| --- | --- |
| `/dv set add 2` | Grant access to connected player ID 2. |
| `/dv set add PlayerName` | Grant access by full connected username. |
| `/dv set add 2 3 "Player Name"` | Grant access to several players in one command. |
| `/dv set remove 2 3` | Revoke access from the specified connected players. |
| `/dv set list` | Show the owner and all saved admins, including offline admins. |
| `/dv set remove account:12345` | Revoke access using the permanent BeamMP account ID shown in the permissions list, even while the player is offline. |
| `/dv set reset` | Remove every added admin; retain the configured owner. Does not delete vehicles. |

Add/remove accepts full usernames or current server player IDs. Use quotes for names containing spaces or entirely numeric usernames. All targets in a batch must be valid before anything is saved. Adding an existing admin or removing someone without access is harmless.

Permissions are saved by permanent BeamMP account ID, so they follow the account after reconnects, username changes, or server restarts. The stored username is the name seen when access was granted and is only a label. Session IDs never become saved permissions.

The mod creates `BeamMP-Delete-Vehicle-permissions.json` in the server's working directory (normally beside the server executable). `PERMISSIONS_FILE` near the top of `Main.lua` controls this location. Keep this file when updating the mod, but exclude your own permissions file from public downloads. Stop the server before manually editing it.

If loading the file fails, added admins are denied access and the owner receives an error when managing permissions. Restore the saved file and restart, or use `/dv set reset` to create an empty list. A save failure is reported without applying the requested permission changes.

## Vehicle commands

`/dvhelp` privately shows commands and examples. `/help` passes through for other mods.

- `/dv list PlayerName` or `/dv list 2` shows vehicle IDs in order, with model names, available configuration names, and a delete command for each.
- `/dv list "Player Name"` supports names with spaces.
- `/dv 2` or `/dv PlayerName` deletes **all** vehicles belonging to that player.
- `/dv 2 0` or `/dv PlayerName 0` deletes only their vehicle ID 0.
- `/dv "123"` targets the username 123; `/dv 123` targets session player ID 123.
- Quote usernames that match subcommands: `/dv "list"` or `/dv "set"`.

Usernames match the full connected name, ignoring letter case. Partial names and ambiguous matches are rejected. Invalid vehicle IDs are rejected without deleting anything. Listing vehicles never deletes them.

Example list entry:

```text
Vehicle ID 0 - pickup (config: base) - delete with: /dv 2 0
```

Model names are internal BeamNG names, including mod models. Missing or unreadable details show `Unknown model`; IDs remain available. Deletion confirmations include the target's username and session player ID.

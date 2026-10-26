# BeamMP Delete Vehicle Mod

A BeamMP mod for finding and deleting players' vehicles, with an in-game Delete Vehicle UI app and visual location markers. The server owner can grant access to multiple admins through the app or chat.

## Installation

1. Use BeamMP Server 3.1.0 or newer.
2. Create `Resources/Server/BeamMP-Delete-Vehicle` inside your server folder.
3. For a source download, copy `BeamMP-Delete-Vehicle/Server/Main.lua` into that folder. The ready-to-install release ZIP already contains the correct `Resources` layout; merge its `Resources` folder into your server folder.
4. For a source download, copy `BeamMP-Delete-Vehicle/Client/BeamMP-Delete-Vehicle-Locator.zip` into `Resources/Client` without extracting it. For this mod, install the ZIP only; leave `ClientSource` out of `Resources/Client`. Other mods can stay in place. BeamMP downloads it to players when they join.
5. Configure the owner username below, then start or restart the server. Reconnect after installing or updating the client ZIP.

## In-game UI app

Update **both** the server script and client ZIP, restart the server, and reconnect. In BeamNG's **UI Apps** editor, choose **Add App → Delete Vehicle**, then save the layout. The existing locator ZIP now contains both the locator and the UI app.

- Choose a player by username and player ID. Their spawned vehicles show model/configuration and vehicle ID.
- Use **Locate vehicle** to identify the vehicle in the world, then **Delete…**. Check the displayed owner and vehicle before confirming deletion.
- The owner's **Permissions** tab can grant access to connected registered players, remove saved admins (including offline accounts), and reset all added admins. Removal and reset ask for confirmation.
- Lists refresh automatically every five seconds; the refresh button updates them immediately. If a player reconnects or a vehicle changes, stale selections are rejected and must be selected again.
- The app shows connection and access status. Vehicle management remains protected by server-side permission checks. Existing chat commands still work.

The public release has no owner configured. Keep your configured username when updating a private installation, or set it as described below. Added admins see vehicle controls; only the owner receives permission-management data.

### Quick UI test

Join your test server as the configured owner, spawn two different vehicles, and add the app. Select yourself, locate each vehicle, and check that **Keep unchanged** cancels deletion. Confirm deletion of one vehicle and verify that only that vehicle disappears. Test granting and revoking another registered player's access when a second player is available.

## Owner configuration

The public version ships with no owner configured. Set this line near the top of `Main.lua` to the owner's registered BeamMP username:

```lua
local ALLOWED_USERNAME = "YourUsername"
```

Matching ignores letter case. An empty username disables all `/dv` commands, even for saved admins. `/dvhelp` remains available to everyone. Guest accounts cannot receive admin permissions. Player ID 0 has no special access.

The owner always has access and is the only person who can add, remove, list, or reset admins. Added admins can list, locate, and delete vehicles, but cannot manage permissions. Change the owner by editing this configuration, not through chat.

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
- `/dv locate 2 0` or `/dv locate "Player Name" 0` marks that exact vehicle for 60 seconds, visible only to the requesting admin.
- `/dv locate clear` removes your current marker. A new locate command replaces the previous target.
- `/dv 2` or `/dv PlayerName` deletes **all** vehicles belonging to that player.
- `/dv 2 0` or `/dv PlayerName 0` deletes only their vehicle ID 0.
- `/dv "123"` targets the username 123; `/dv 123` targets session player ID 123.
- Quote usernames that match subcommands: `/dv "list"`, `/dv "set"`, or `/dv "locate"`.

Usernames match the full connected name, ignoring letter case. Partial names and ambiguous matches are rejected. Invalid vehicle IDs are rejected without deleting anything. Listing vehicles never deletes them.

Example list entry:

```text
Vehicle ID 0 - pickup (config: base) - locate: /dv locate 2 0 - delete: /dv 2 0
```

Model names are internal BeamNG names, including mod models. Missing or unreadable details show `Unknown model`; IDs remain available. Deletion confirmations include the target's username and session player ID.

## Vehicle locator

The orange beacon follows the selected vehicle and displays its owner, player ID, vehicle ID, model/configuration, and distance from your camera in metres. The text label is drawn through scenery; turn your camera toward the vehicle to see it. It does not move your camera, teleport vehicles, or replace your GPS route.

The marker stops after 60 seconds, when cleared, when the target is removed/replaced, or when leaving the map. The target must be spawned locally: if it is in BeamMP's vehicle queue, apply queued vehicles and try again. After five seconds without a local vehicle, the locator displays an explanation and stops. A server message that a locator was requested confirms dispatch, not that the client rendered it. If no marker or client notification appears, check that the locator ZIP was installed and reconnect.

### Solo test

1. In your private test copy, set the owner username to your own registered BeamMP username.
2. Install the server script and client ZIP, restart the server, then join.
3. Spawn two different vehicles and run `/dv list YourUsername`.
4. Use the listed `/dv locate` command for each vehicle. Confirm the marker identifies the selected vehicle and follows it when moved.
5. Run `/dv locate clear`, then try another marker and check that it expires after 60 seconds.
6. Verify that locating never removes either vehicle.

### Rebuilding the client ZIP

Editable client Lua and UI assets are in `BeamMP-Delete-Vehicle/ClientSource`. From the repository root, run `python tools/build_client.py` after changing them, then install the rebuilt `Client/BeamMP-Delete-Vehicle-Locator.zip` and reconnect. Do not install the source folder directly in `Resources/Client`.
## Automated checks

From the repository root, install Python's `lupa` package, then run:

```sh
python -m pip install lupa
python tests/test_ui_server.py
python tests/test_client.py
```

These run server permission/UI regressions and client bridge/locator checks with mocked game APIs, and verify that the client ZIP matches its source. They do not replace testing inside BeamNG and BeamMP.

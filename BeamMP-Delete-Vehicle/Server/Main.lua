-- Set the owner's BeamMP username. The owner manages permissions; empty disables /dv.
local ALLOWED_USERNAME = ""
-- Relative to the server's working directory, outside the hot-reloaded plugin folder.
local PERMISSIONS_FILE = "BeamMP-Delete-Vehicle-permissions.json"

local admins = {}
local permissions_error

local uiSubscribers, uiSelected, uiSnapshots, uiRate = {}, {}, {}, {}
local playerEpoch, vehicleEpoch = {}, {}
local nextUIToken = 0
local function sendChat(pid, message)
    MP.SendChatMessage(pid, message)
    if uiSubscribers[pid] then MP.TriggerClientEvent(pid, "DVUINotice", Util.JsonEncode({text = message})) end
end

local function loadPermissions()
    if not FS.Exists(PERMISSIONS_FILE) then return end
    local file, err = io.open(PERMISSIONS_FILE, "r")
    if not file then permissions_error = err; return end
    local contents = file:read("*a")
    file:close()
    local ok, data = pcall(Util.JsonDecode, contents or "")
    if not ok or type(data) ~= "table" or data.version ~= 1
        or (data.admins ~= nil and type(data.admins) ~= "table") then
        permissions_error = "Invalid permissions file. Restore it or use /dv set reset."
        return
    end
    for id, name in pairs(data.admins or {}) do
        if type(id) ~= "string" or not id:match("^[1-9]%d*$")
            or type(name) ~= "string" or name == "" then
            permissions_error = "Invalid admin entry. Restore the file or use /dv set reset."
            return
        end
    end
    admins = data.admins or {}
end

local function savePermissions(updated)
    local data = { version = 1 }
    -- Omit an empty map: BeamMP's encoder may encode an empty Lua table as null.
    if next(updated) then data.admins = updated end
    local ok, encoded = pcall(Util.JsonEncode, data)
    if not ok or type(encoded) ~= "string" then return false, "Could not encode permissions." end
    local temporary = PERMISSIONS_FILE .. ".tmp"
    local file, err = io.open(temporary, "w")
    if not file then return false, err end
    local written, write_error = file:write(encoded)
    local closed, close_error = file:close()
    if not written or not closed then return false, write_error or close_error end
    -- Replace the saved file only after a complete write; commit memory only on success.
    local renamed, rename_error = FS.Rename(temporary, PERMISSIONS_FILE)
    if not renamed then return false, rename_error end
    admins = updated
    permissions_error = nil
    return true
end

local function accountId(player_id)
    if MP.IsPlayerGuest(player_id) then return nil end
    local identifiers = MP.GetPlayerIdentifiers(player_id)
    local id = type(identifiers) == "table" and identifiers.beammp
    if type(id) == "number" and id > 0 and id < math.huge and id % 1 == 0 then
        id = string.format("%.0f", id)
    end
    if type(id) == "string" and id:match("^[1-9]%d*$") then return id end
end

local function isOwner(player_id)
    local username = MP.GetPlayerName(player_id)
    return ALLOWED_USERNAME ~= "" and type(username) == "string"
        and username:lower() == ALLOWED_USERNAME:lower() and not MP.IsPlayerGuest(player_id)
end

-- Permission commands can take multiple targets; quotes keep names with spaces together.
local function permissionTargets(text)
    local targets = {}
    while text ~= "" do
        local quoted = text:sub(1, 1) == '"'
        local value, rest
        if quoted then
            value, rest = text:match('^"([^"]+)"(.*)$')
            if not value or (rest ~= "" and not rest:match("^%s")) then return nil end
        else
            value, rest = text:match("^(%S+)(.*)$")
            if not value then return nil end
        end
        table.insert(targets, { value = value, quoted = quoted })
        text = rest:match("^%s*(.-)%s*$")
    end
    return targets
end

local function connectedTarget(target)
    local players = MP.GetPlayers()
    if not target.quoted and target.value:match("^%d+$") then
        local id = tonumber(target.value)
        if id and players[id] then return id, players[id] end
        return nil, "Player ID " .. target.value .. " is not connected."
    end
    local found
    for id, name in pairs(players) do
        if name:lower() == target.value:lower() then
            if found ~= nil then return nil, "Ambiguous username; use a player ID." end
            found = id
        end
    end
    if found ~= nil then return found, players[found] end
    return nil, "No connected player named " .. target.value .. "."
end

local function managePermissions(player_id, arguments)
    local action, rest = arguments:match("^(%S+)%s*(.-)%s*$")
    action = action and action:lower()
    local function reply(message) sendChat(player_id, message) end
    local function commit(updated, message)
        local ok, err = savePermissions(updated)
        if ok then reply(message)
        else reply("Error: Permissions were not changed: " .. tostring(err)) end
    end

    if action == "reset" and rest == "" then
        commit({}, "Removed all added admins. The configured owner still has access.")
        return
    end
    if permissions_error then
        reply("Error: " .. permissions_error)
        return
    end
    if action == "list" and rest == "" then
        reply("Owner: " .. ALLOWED_USERNAME)
        local ids = {}
        for id in pairs(admins) do table.insert(ids, id) end
        table.sort(ids)
        if #ids == 0 then reply("No added admins.") end
        for _, id in ipairs(ids) do
            reply(admins[id] .. " (BeamMP account " .. id .. ") - remove: /dv set remove account:" .. id)
        end
        return
    end
    if (action ~= "add" and action ~= "remove") or rest == "" then
        reply('Usage: /dv set add|remove <player_id|username> [...] or /dv set list|reset')
        return
    end
    local targets = permissionTargets(rest)
    if not targets or #targets == 0 then reply("Error: Invalid targets or unmatched quotes."); return end
    local updated = {}
    for id, name in pairs(admins) do updated[id] = name end
    local changed = 0
    for _, target in ipairs(targets) do
        local id = not target.quoted and target.value:match("^account:([1-9]%d*)$")
        local name
        if id then
            if action ~= "remove" then reply("Error: Add players by their connected username or player ID."); return end
            name = updated[id]
        else
            local pid, result = connectedTarget(target)
            if pid == nil then reply("Error: " .. result .. " No permissions were changed."); return end
            name = result
            if isOwner(pid) then reply("Error: The owner is configured in Main.lua and cannot be added or removed here."); return end
            id = accountId(pid)
            if not id then reply("Error: " .. name .. " needs a registered BeamMP account. No permissions were changed."); return end
        end
        if action == "add" then
            if not updated[id] then changed = changed + 1 end
            updated[id] = name
        else
            if updated[id] then changed = changed + 1 end
            updated[id] = nil
        end
    end
    commit(updated, (action == "add" and "Granted access to " or "Removed access from ") .. changed .. " player(s).")
end

loadPermissions()
if permissions_error then print("[Delete Vehicle] " .. permissions_error) end

-- Vehicle packets may have a network prefix before their JSON object.
local function vehicleDescription(raw)
    if type(raw) ~= "string" then return "Unknown model" end
    local start = raw:find("{", 1, true)
    if not start then return "Unknown model" end
    local ok, data = pcall(Util.JsonDecode, raw:sub(start))
    if not ok or type(data) ~= "table" then return "Unknown model" end

    local function label(value)
        if type(value) ~= "string" then return nil end
        value = value:gsub("%c", " "):gsub("%^%d", ""):sub(1, 60)
        if value == "" then return nil end
        return value
    end

    -- jbm is the internal model name, which also works for mod vehicles.
    local model = label(data.jbm) or "Unknown model"
    local config = type(data.vcf) == "table" and data.vcf.partConfigFilename
    if type(config) == "string" then
        config = label(config:match("([^/\\]+)%.pc$"))
    else
        config = nil
    end
    if config then return model .. " (config: " .. config .. ")" end
    return model
end

local function handleChat(player_id, sender_name, message)
    -- Safety check: If the message is completely empty or doesn't start with a slash, let it go to regular chat
    if not message or message:sub(1, 1) ~= "/" then 
        return 0 
    end

    local command, arguments = message:match("^(%S+)%s*(.-)%s*$")
    command = command:lower()

    if command == "/dvhelp" then
        sendChat(player_id, "BeamMP Delete Vehicle - Help")
        sendChat(player_id, "/dv list <player_id|username> - show vehicle IDs, models and available configurations.")
        sendChat(player_id, "/dv locate <player_id|username> <vehicle_id> - mark a vehicle for 60 seconds. /dv locate clear - hide the marker.")
        sendChat(player_id, "/dv <player_id|username> <vehicle_id> - delete one vehicle.")
        sendChat(player_id, "/dv <player_id|username> - delete ALL vehicles belonging to that player.")
        sendChat(player_id, 'Examples: /dv list 2 | /dv list "Player Name" | /dv 2 0')
        sendChat(player_id, 'Use the full username (case-insensitive), with "quotes" for spaces or numeric usernames.')
        sendChat(player_id, "Player IDs are current server session IDs. The owner and saved admins can use /dv.")
        sendChat(player_id, "Owner only: /dv set add|remove <player_id|username> [...] | /dv set list | /dv set reset")
        sendChat(player_id, 'Example: /dv set add 2 3 "Player Name". Reset removes all added admins, keeping the owner.')
        return 1
    end

    -- ========================================================================
    -- THE ADMIN PROTECTION BLOCK: Intercepts the monitored slash command
    -- ========================================================================
    if command == "/dv" then
        
        local owner = isOwner(player_id)
        local id = not owner and accountId(player_id)
        if ALLOWED_USERNAME == "" or (not owner and (permissions_error or not id or not admins[id])) then
            sendChat(player_id, "Error: You do not have admin privileges to use this command.")
            return 1 -- Intercepts the text to prevent standard players from spamming it
        end

        -- ==========================================
        -- COMMAND: Delete Vehicles (/dv)
        -- ==========================================
        -- Reserve unquoted subcommands; quoted usernames remain valid targets.
        local first_argument, remaining = arguments:match("^(%S+)%s*(.*)$")
        if first_argument and first_argument:lower() == "set" then
            if not owner then
                sendChat(player_id, "Error: Only the configured owner can manage permissions.")
            else
                managePermissions(player_id, remaining)
            end
            return 1
        end
        local list_only = first_argument ~= nil and first_argument:lower() == "list"
        local locate_only = first_argument ~= nil and first_argument:lower() == "locate"
        if locate_only and remaining:lower() == "clear" then
            local sent = MP.TriggerClientEvent(player_id, "DVLocatorClear", "")
            sendChat(player_id, sent and "Locator clear request sent." or "Error: Could not send locator clear request.")
            return 1
        end
        if list_only or locate_only then
            arguments = remaining
        end

        -- Quoted targets support spaces and distinguish numeric usernames from IDs.
        local target, vehicle_argument
        local quoted = arguments:sub(1, 1) == '"'
        if quoted then
            target, vehicle_argument = arguments:match('^"([^"]+)"%s*(.*)$')
            if target and vehicle_argument ~= "" and not arguments:match('^"[^"]+"%s+') then
                target = nil
            end
        else
            target, vehicle_argument = arguments:match("^(%S+)%s*(.*)$")
        end

        if not target then
            sendChat(player_id, locate_only and 'Usage: /dv locate <player_id|username> <vehicle_id> or /dv locate clear'
                or 'Usage: /dv <player_id|username> [vehicle_id] or /dv list <player_id|username>. Use "quotes" for names with spaces.')
            return 1
        end

        if list_only and vehicle_argument ~= "" then
            sendChat(player_id, "Usage: /dv list <player_id|username>")
            return 1
        end

        -- An invalid vehicle argument must never fall back to deleting all vehicles.
        local specific_vehicle_id
        if vehicle_argument ~= "" then
            specific_vehicle_id = tonumber(vehicle_argument)
            if not vehicle_argument:match("^%d+$") or not specific_vehicle_id
                or specific_vehicle_id == math.huge then
                sendChat(player_id, "Error: Vehicle ID must be a non-negative whole number.")
                return 1
            end
        end
        if locate_only and specific_vehicle_id == nil then
            sendChat(player_id, "Usage: /dv locate <player_id|username> <vehicle_id>. Find IDs with /dv list <player>.")
            return 1
        end

        local players = MP.GetPlayers()
        local target_id
        if not quoted and target:match("^%d+$") then
            target_id = tonumber(target)
            if not target_id or not players[target_id] then
                sendChat(player_id, "Error: Player ID " .. target .. " is not connected.")
                return 1
            end
        else
            -- Exact, case-insensitive matching prevents deleting a partial-name match.
            for id, name in pairs(players) do
                if name:lower() == target:lower() then
                    if target_id ~= nil then
                        sendChat(player_id, "Error: Multiple players match that username. Use their player ID.")
                        return 1
                    end
                    target_id = id
                end
            end
            if target_id == nil then
                sendChat(player_id, "Error: No connected player has the username " .. target .. ".")
                return 1
            end
        end

        local target_label = players[target_id] .. " (Player ID " .. target_id .. ")"

        local vehicles = MP.GetPlayerVehicles(target_id)
        if not vehicles or next(vehicles) == nil then
            sendChat(player_id, "Error: Player ID " .. target_id .. " has no active vehicles.")
            return 1
        end

        if locate_only then
            if not vehicles[specific_vehicle_id] then
                sendChat(player_id, "Error: Vehicle ID " .. specific_vehicle_id .. " does not belong to " .. target_label)
                return 1
            end
            local payload = {
                serverVehicleID = target_id .. "-" .. specific_vehicle_id,
                label = target_label .. " | Vehicle ID " .. specific_vehicle_id .. " | " .. vehicleDescription(vehicles[specific_vehicle_id]),
                duration = 60
            }
            local sent = MP.TriggerClientEvent(player_id, "DVLocatorShow", Util.JsonEncode(payload))
            if sent then
                sendChat(player_id, "Locator requested for vehicle ID " .. specific_vehicle_id .. " owned by " .. target_label .. ". Requires the locator client ZIP; use /dv locate clear to stop.")
            else
                sendChat(player_id, "Error: Could not send the locator request. Try again after reconnecting.")
            end
            return 1
        end

        if list_only then
            local vehicle_ids = {}
            for vehicle_id in pairs(vehicles) do
                table.insert(vehicle_ids, vehicle_id)
            end
            table.sort(vehicle_ids)
            sendChat(player_id, "Vehicles for " .. target_label .. ":")
            for _, vehicle_id in ipairs(vehicle_ids) do
                sendChat(player_id, "Vehicle ID " .. vehicle_id .. " - " .. vehicleDescription(vehicles[vehicle_id]) .. " - locate: /dv locate " .. target_id .. " " .. vehicle_id .. " - delete: /dv " .. target_id .. " " .. vehicle_id)
            end
            return 1
        end

        -- Choice 1: Delete a specific vehicle ID if it was provided in slot 3
        if specific_vehicle_id then
            if vehicles[specific_vehicle_id] then
                MP.RemoveVehicle(target_id, specific_vehicle_id)
                sendChat(player_id, "Successfully deleted vehicle ID " .. specific_vehicle_id .. " from " .. target_label)
            else
                sendChat(player_id, "Error: Vehicle ID " .. specific_vehicle_id .. " does not belong to Player ID " .. target_id)
            end
        -- Choice 2: Delete ALL vehicles if no vehicle ID was specified
        else
            local count = 0
            for vehicle_id, _ in pairs(vehicles) do
                MP.RemoveVehicle(target_id, vehicle_id)
                count = count + 1
            end
            sendChat(player_id, "Successfully deleted " .. count .. " vehicle(s) from " .. target_label)
        end
        return 1 -- Clean intercept, completely strips command text from global chat windows
    end

    -- If a message starts with a slash but isn't our admin command, allow it to process normally
    return 0 
end

local function uiAccess(pid)
    local owner = isOwner(pid)
    local account = not owner and accountId(pid)
    return ALLOWED_USERNAME ~= "" and (owner or (not permissions_error and account and admins[account] ~= nil)), owner
end

local function sendUIState(pid)
    local allowed, owner = uiAccess(pid)
    if not allowed then
        uiSnapshots[pid] = nil
        MP.TriggerClientEvent(pid, "DVUIState", Util.JsonEncode({connected = true, allowed = false,
            configured = ALLOWED_USERNAME ~= ""}))
        return
    end
    local previous, snapshots = uiSnapshots[pid] or {}, {}
    local function tokenFor(key, snapshot)
        local old = previous[key]
        if old and old.identity == snapshot.identity and old.epoch == snapshot.epoch and old.raw == snapshot.raw then
            snapshot.token = old.token
        else nextUIToken = nextUIToken + 1; snapshot.token = "t" .. nextUIToken end
        snapshots[key] = snapshot
        return snapshot.token
    end
    local players, vehicles, permissions = {}, {}, {}
    local online = MP.GetPlayers()
    if not uiSelected[pid] or not online[uiSelected[pid]] then
        uiSelected[pid] = online[pid] and pid or nil
    end
    for id, username in pairs(online) do
        local account = accountId(id)
        local identity = username .. ":" .. (account or "guest") .. ":" .. (playerEpoch[id] or 0)
        local listed = MP.GetPlayerVehicles(id) or {}
        local count = 0
        for _ in pairs(listed) do count = count + 1 end
        local playerToken = tokenFor("p:" .. id, {kind = "player", pid = id, identity = identity})
        local targetOwner = isOwner(id)
        table.insert(players, {id = id, name = username, count = count, token = playerToken,
            role = targetOwner and "Owner" or (account and admins[account] and "Admin" or "Player"),
            canGrant = owner and account ~= nil and not targetOwner and admins[account] == nil})
        if id == uiSelected[pid] then
            for vid, raw in pairs(listed) do
                local key = id .. ":" .. vid
                local token = tokenFor(key, {kind = "vehicle", pid = id, vid = vid, identity = identity,
                    raw = raw, epoch = vehicleEpoch[key] or 0})
                table.insert(vehicles, {id = vid, description = vehicleDescription(raw), token = token})
            end
        end
    end
    table.sort(players, function(a, b) return a.id < b.id end)
    table.sort(vehicles, function(a, b) return a.id < b.id end)
    if owner then
        for account, username in pairs(admins) do table.insert(permissions, {account = account, name = username}) end
        table.sort(permissions, function(a, b) return a.name:lower() < b.name:lower() end)
    end
    uiSnapshots[pid] = snapshots
    MP.TriggerClientEvent(pid, "DVUIState", Util.JsonEncode({connected = true, allowed = true, owner = owner,
        configured = true, players = players, selectedId = uiSelected[pid], vehicles = vehicles,
        admins = owner and permissions or nil, ownerName = owner and ALLOWED_USERNAME or nil,
        permissionsError = owner and permissions_error or nil}))
end

local function publishUI()
    if next(uiSubscribers) == nil then return end
    local players = MP.GetPlayers()
    for pid in pairs(uiSubscribers) do
        if players[pid] then sendUIState(pid) else uiSubscribers[pid], uiSnapshots[pid] = nil, nil end
    end
end

function OnChatHandler(pid, sender, message)
    local result = handleChat(pid, sender, message)
    if result == 1 then publishUI() end
    return result
end

local function validUIInteger(value)
    return type(value) == "number" and value >= 0 and value <= 2147483647 and value % 1 == 0
end

function DVUIAction(pid, raw)
    if MP.GetPlayers()[pid] == nil or type(raw) ~= "string" or #raw > 512 then return end
    local ok, data = pcall(Util.JsonDecode, raw)
    if not ok or type(data) ~= "table" then return end
    local actions = {refresh = true, delete = true, locate = true, clear = true, grant = true,
        remove = true, reset = true, unsubscribe = true}
    if not actions[data.action] then return end
    if data.action == "unsubscribe" then
        uiSubscribers[pid], uiSnapshots[pid], uiSelected[pid], uiRate[pid] = nil, nil, nil, nil
        return
    end
    local now = os.time()
    if not uiRate[pid] or uiRate[pid].time ~= now then uiRate[pid] = {time = now, count = 0} end
    if uiRate[pid].count >= 8 then return end
    uiRate[pid].count = uiRate[pid].count + 1
    uiSubscribers[pid] = true
    if data.action == "refresh" then
        if validUIInteger(data.value) then uiSelected[pid] = data.value end
        sendUIState(pid)
        return
    end
    local allowed, owner = uiAccess(pid)
    if not allowed then sendUIState(pid); return end
    if data.action == "grant" or data.action == "remove" or data.action == "reset" then
        if not owner then sendChat(pid, "Error: Only the owner can manage permissions."); return end
    end
    if data.action == "clear" then OnChatHandler(pid, "", "/dv locate clear"); return end
    if data.action == "reset" then OnChatHandler(pid, "", "/dv set reset"); return end
    if data.action == "remove" then
        if type(data.value) == "string" and data.value:match("^[1-9]%d*$") then
            OnChatHandler(pid, "", "/dv set remove account:" .. data.value)
        end
        return
    end
    local selected
    for _, snapshot in pairs(uiSnapshots[pid] or {}) do
        if snapshot.token == data.value then selected = snapshot; break end
    end
    local valid = selected ~= nil
    if valid then
        local username = MP.GetPlayers()[selected.pid]
        local account = username and accountId(selected.pid)
        local identity = username and (username .. ":" .. (account or "guest") .. ":" .. (playerEpoch[selected.pid] or 0))
        valid = identity == selected.identity
        if selected.kind == "vehicle" then
            local current = MP.GetPlayerVehicles(selected.pid) or {}
            valid = valid and current[selected.vid] == selected.raw
                and (vehicleEpoch[selected.pid .. ":" .. selected.vid] or 0) == selected.epoch
        end
    end
    if not valid then sendChat(pid, "The selection changed. Refresh and choose the player or vehicle again."); sendUIState(pid); return end
    if data.action == "grant" and selected.kind == "player" then
        OnChatHandler(pid, "", "/dv set add " .. selected.pid)
    elseif (data.action == "delete" or data.action == "locate") and selected.kind == "vehicle" then
        local prefix = data.action == "locate" and "/dv locate " or "/dv "
        OnChatHandler(pid, "", prefix .. selected.pid .. " " .. selected.vid)
    end
end

function DVUIVehicleChanged(pid, vid)
    local key = pid .. ":" .. vid
    vehicleEpoch[key] = (vehicleEpoch[key] or 0) + 1
    return 0
end

function DVUIDisconnect(pid)
    playerEpoch[pid] = (playerEpoch[pid] or 0) + 1
    uiSubscribers[pid], uiSnapshots[pid], uiSelected[pid], uiRate[pid] = nil, nil, nil, nil
end

MP.RegisterEvent("onChatMessage", "OnChatHandler")
MP.RegisterEvent("DVUIAction", "DVUIAction")
MP.RegisterEvent("onPlayerDisconnect", "DVUIDisconnect")
MP.RegisterEvent("onVehicleSpawn", "DVUIVehicleChanged")
MP.RegisterEvent("onVehicleEdited", "DVUIVehicleChanged")
MP.RegisterEvent("onVehicleDeleted", "DVUIVehicleChanged")

print("--------------------------------------------------")
print(" SUCCESSFULY LOADED BEAMMP DELETE VEHICLE MOD       ")
print("--------------------------------------------------")

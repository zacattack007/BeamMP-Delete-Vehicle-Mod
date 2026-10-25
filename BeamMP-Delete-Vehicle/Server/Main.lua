-- Set this to the BeamMP username allowed to use /dv. Empty disables access.
local ALLOWED_USERNAME = "zacattack"

function OnChatHandler(player_id, sender_name, message)
    -- Safety check: If the message is completely empty or doesn't start with a slash, let it go to regular chat
    if not message or message:sub(1, 1) ~= "/" then 
        return 0 
    end

    local command, arguments = message:match("^(%S+)%s*(.-)%s*$")
    command = command:lower()

    -- ========================================================================
    -- THE ADMIN PROTECTION BLOCK: Intercepts the monitored slash command
    -- ========================================================================
    if command == "/dv" then
        
        -- Check the server-reported username, independent of the current player ID.
        local username = MP.GetPlayerName(player_id)
        if ALLOWED_USERNAME == "" or type(username) ~= "string"
            or username:lower() ~= ALLOWED_USERNAME:lower() then
            MP.SendChatMessage(player_id, "Error: You do not have admin privileges to use this command.")
            return 1 -- Intercepts the text to prevent standard players from spamming it
        end

        -- ==========================================
        -- COMMAND: Delete Vehicles (/dv)
        -- ==========================================
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
            MP.SendChatMessage(player_id, 'Usage: /dv <player_id|username> [vehicle_id]. Use "quotes" for names with spaces.')
            return 1
        end

        -- An invalid vehicle argument must never fall back to deleting all vehicles.
        local specific_vehicle_id
        if vehicle_argument ~= "" then
            specific_vehicle_id = tonumber(vehicle_argument)
            if not vehicle_argument:match("^%d+$") or not specific_vehicle_id
                or specific_vehicle_id == math.huge then
                MP.SendChatMessage(player_id, "Error: Vehicle ID must be a non-negative whole number.")
                return 1
            end
        end

        local players = MP.GetPlayers()
        local target_id
        if not quoted and target:match("^%d+$") then
            target_id = tonumber(target)
            if not target_id or not players[target_id] then
                MP.SendChatMessage(player_id, "Error: Player ID " .. target .. " is not connected.")
                return 1
            end
        else
            -- Exact, case-insensitive matching prevents deleting a partial-name match.
            for id, name in pairs(players) do
                if name:lower() == target:lower() then
                    if target_id ~= nil then
                        MP.SendChatMessage(player_id, "Error: Multiple players match that username. Use their player ID.")
                        return 1
                    end
                    target_id = id
                end
            end
            if target_id == nil then
                MP.SendChatMessage(player_id, "Error: No connected player has the username " .. target .. ".")
                return 1
            end
        end

        local vehicles = MP.GetPlayerVehicles(target_id)
        if not vehicles or next(vehicles) == nil then
            MP.SendChatMessage(player_id, "Error: Player ID " .. target_id .. " has no active vehicles.")
            return 1
        end

        -- Choice 1: Delete a specific vehicle ID if it was provided in slot 3
        if specific_vehicle_id then
            if vehicles[specific_vehicle_id] then
                MP.RemoveVehicle(target_id, specific_vehicle_id)
                MP.SendChatMessage(player_id, "Successfully deleted vehicle ID " .. specific_vehicle_id .. " from Player ID " .. target_id)
            else
                MP.SendChatMessage(player_id, "Error: Vehicle ID " .. specific_vehicle_id .. " does not belong to Player ID " .. target_id)
            end
        -- Choice 2: Delete ALL vehicles if no vehicle ID was specified
        else
            local count = 0
            for vehicle_id, _ in pairs(vehicles) do
                MP.RemoveVehicle(target_id, vehicle_id)
                count = count + 1
            end
            MP.SendChatMessage(player_id, "Successfully deleted " .. count .. " vehicle(s) from Player ID " .. target_id)
        end
        return 1 -- Clean intercept, completely strips command text from global chat windows
    end

    -- If a message starts with a slash but isn't our admin command, allow it to process normally
    return 0 
end

MP.RegisterEvent("onChatMessage", "OnChatHandler")

print("--------------------------------------------------")
print(" SUCCESSFULY LOADED BEAMMP DELETE VEHICLE MOD       ")
print("--------------------------------------------------")
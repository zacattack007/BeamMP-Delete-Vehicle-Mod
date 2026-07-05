function OnChatHandler(player_id, sender_name, message)
    -- Safety check: If the message is completely empty or doesn't start with a slash, let it go to regular chat
    if not message or message:sub(1, 1) ~= "/" then 
        return 0 
    end

    -- Split the string cleanly by spaces into a structured table array
    local args = {}
    for arg in message:gmatch("%S+") do
        table.insert(args, arg)
    end
    
    -- Safety exit if string parsing failed completely
    if #args == 0 then return 1 end

    -- DIRECT MATCHING: Target the explicit array slot for the command word to avoid table-to-string crashes
    local command = args[1]:lower()

    -- ========================================================================
    -- THE ADMIN PROTECTION BLOCK: Intercepts the monitored slash command
    -- ========================================================================
    if command == "/dv" then
        
        -- SECURE HOST LOCK: If the sender is NOT Player ID 0, reject the command immediately
        if player_id ~= 0 then
            MP.SendChatMessage(player_id, "Error: You do not have admin privileges to use this command.")
            return 1 -- Intercepts the text to prevent standard players from spamming it
        end

        -- ==========================================
        -- COMMAND: Delete Vehicles (/dv)
        -- ==========================================
        -- Explicitly parse individual numerical indexes safely out of the array
        local target_id = tonumber(args[2])
        local specific_vehicle_id = tonumber(args[3])

        if not target_id then
            MP.SendChatMessage(player_id, "Usage: /dv [player_id] or /dv [player_id] [vehicle_id]")
            return 1
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
print(" [SUCCESS] Corrected Indexing Script Active!       ")
print("--------------------------------------------------")
local M = {}
local target
local registeredWith
local handlerName = "beammpDeleteVehicleLocator"

local uiListening = false
local function uiHook(event, data)
    if guihooks then guihooks.trigger(event, data) end
end
local function receiveState(raw)
    if type(raw) ~= "string" then return end
    local ok, data = pcall(jsonDecode, raw)
    if ok and type(data) == "table" then uiHook("DVAppState", data) end
end
local function receiveNotice(raw)
    if type(raw) ~= "string" or #raw > 4096 then return end
    local ok, data = pcall(jsonDecode, raw)
    if ok and type(data) == "table" and type(data.text) == "string" then
        uiHook("DVAppNotice", {text = data.text})
    end
end

local function notify(text)
    if ui_message then ui_message(text, 6, "dvLocator") end
    uiHook("DVAppNotice", {text = text})
end

local function clear(reason)
    target = nil
    if reason then notify(reason) end
end

local function receiveShow(raw)
    if type(raw) ~= "string" or #raw > 4096 then return end
    local ok, data = pcall(jsonDecode, raw)
    if not ok or type(data) ~= "table" or type(data.serverVehicleID) ~= "string"
        or not data.serverVehicleID:match("^%d+%-%d+$") or type(data.label) ~= "string" then return end
    target = {
        id = data.serverVehicleID,
        label = data.label:gsub("%c", " "):gsub("%^%d", ""):sub(1, 240),
        -- Fixed client lifetime prevents malformed events from leaving permanent markers.
        remaining = 60,
        missingTime = 0
    }
    notify("Locating " .. target.label .. ". Look for the orange marker; /dv locate clear hides it.")
end

local function receiveClear()
    clear("Vehicle locator cleared.")
end

local function registerHandlers()
    if type(AddEventHandler) == "function" and registeredWith ~= AddEventHandler then
        AddEventHandler("DVLocatorShow", receiveShow, handlerName)
        AddEventHandler("DVLocatorClear", receiveClear, handlerName)
        AddEventHandler("DVUIState", receiveState, handlerName)
        AddEventHandler("DVUINotice", receiveNotice, handlerName)
        registeredWith = AddEventHandler
    end
end

local function uiAction(action, value)
    local actions = {refresh = true, delete = true, locate = true, clear = true, grant = true,
        remove = true, reset = true, unsubscribe = true}
    if not actions[action] then return end
    if action == "refresh" and value ~= nil then
        if type(value) ~= "number" or value < 0 or value > 2147483647 or value % 1 ~= 0 then return end
    elseif action == "delete" or action == "locate" or action == "grant" then
        if type(value) ~= "string" or #value > 32 or not value:match("^t%d+$") then return end
    elseif action == "remove" then
        if type(value) ~= "string" or #value > 32 or not value:match("^[1-9]%d*$") then return end
    end
    if not MPCoreNetwork or not MPCoreNetwork.isMPSession() or type(TriggerServerEvent) ~= "function" then
        uiHook("DVAppState", {connected = false})
        return
    end
    uiListening = action ~= "unsubscribe"
    registerHandlers()
    TriggerServerEvent("DVUIAction", jsonEncode({action = action, value = value}))
end

local function onUpdate(dtReal)
    -- The mod may mount before BeamMP's event functions are ready.
    registerHandlers()
    if not target then return end
    local dt = math.max(0, tonumber(dtReal) or 0)
    target.remaining = target.remaining - dt
    if target.remaining <= 0 then clear("Vehicle locator expired."); return end

    local vehicles = extensions.MPVehicleGE or MPVehicleGE
    local entry = vehicles and vehicles.getVehicleByServerID(target.id)
    if target.entry and target.entry ~= entry then
        clear("Located vehicle was removed or replaced.")
        return
    end
    if entry then target.entry = entry end
    local vehicle = entry and entry.gameVehicleID and be:getObjectByID(entry.gameVehicleID)
    if not vehicle then
        target.missingTime = target.missingTime + dt
        if target.missingTime >= 5 then
            clear("Vehicle is not spawned on your client. Apply queued vehicles, then run /dv locate again.")
        end
        return
    end
    target.missingTime = 0

    local position = vehicle:getPosition()
    local beacon = position + vec3(0, 0, 8)
    local distance = (position - getCameraPosition()):length()
    local label = target.label .. string.format(" | %.0f m from camera", distance)
    debugDrawer:drawCylinder(position, beacon, 0.18, ColorF(1, 0.45, 0, 0.55))
    debugDrawer:drawSphere(position + vec3(0, 0, 2), 0.5, ColorF(1, 0.65, 0, 0.8))
    -- Last argument disables depth testing so the label can be seen behind scenery.
    debugDrawer:drawTextAdvanced(beacon, String(label), ColorF(1, 0.8, 0.2, 1), true, false, ColorI(0, 0, 0, 190), false, false)
end

local function onExtensionUnloaded()
    clear()
    if uiListening and type(TriggerServerEvent) == "function" and MPCoreNetwork and MPCoreNetwork.isMPSession() then
        TriggerServerEvent("DVUIAction", jsonEncode({action = "unsubscribe"}))
    end
    uiListening = false
    if registeredWith and type(RemoveEventHandler) == "function" then
        RemoveEventHandler("DVLocatorShow", handlerName)
        RemoveEventHandler("DVLocatorClear", handlerName)
        RemoveEventHandler("DVUIState", handlerName)
        RemoveEventHandler("DVUINotice", handlerName)
    end
    registeredWith = nil
    uiHook("DVAppState", {connected = false})
end

M.onExtensionLoaded = registerHandlers
M.onUpdate = onUpdate
M.onClientEndMission = function() clear(); uiHook("DVAppState", {connected = false}) end
M.onExtensionUnloaded = onExtensionUnloaded
M.uiAction = uiAction
return M

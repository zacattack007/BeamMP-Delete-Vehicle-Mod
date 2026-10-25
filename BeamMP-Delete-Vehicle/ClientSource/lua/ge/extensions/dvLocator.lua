local M = {}
local target
local registeredWith
local handlerName = "beammpDeleteVehicleLocator"

local function notify(text)
    if ui_message then ui_message(text, 6, "dvLocator") end
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
        registeredWith = AddEventHandler
    end
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
    if registeredWith and type(RemoveEventHandler) == "function" then
        RemoveEventHandler("DVLocatorShow", handlerName)
        RemoveEventHandler("DVLocatorClear", handlerName)
    end
    registeredWith = nil
end

M.onExtensionLoaded = registerHandlers
M.onUpdate = onUpdate
M.onClientEndMission = function() clear() end
M.onExtensionUnloaded = onExtensionUnloaded
return M

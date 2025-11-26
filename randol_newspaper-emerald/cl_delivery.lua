local Config = lib.require('shared')
local startPed, pedInteract
local delay, clockedIn = false, false
local myData = {}
local workZones = {}
local blipStore = {}
local netid
local activeWaypoint = nil
local outOfPapers = false

-- Track which deliveries have been completed (by their original index)
local completedDeliveries = {}
local remainingCount = 0
local isValidatingDrop = false -- Flag to prevent race condition with inventory events

if Config.EnableBlip then
    local NEWS_BLIP = AddBlipForCoord(Config.PedCoords.xyz)
    SetBlipSprite(NEWS_BLIP, 590)
    SetBlipDisplay(NEWS_BLIP, 4)
    SetBlipScale(NEWS_BLIP, 0.80)
    SetBlipAsShortRange(NEWS_BLIP, true)
    SetBlipColour(NEWS_BLIP, 1)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName('Newspaper Delivery')
    EndTextCommandSetBlipName(NEWS_BLIP)
end

local function addTargetEntity(entity, options, distance)
    if GetResourceState('ox_target') == 'started' then
        for _, option in ipairs(options) do
            option.distance = distance
            option.onSelect = option.action
            option.action = nil
        end
        exports.ox_target:addLocalEntity(entity, options)
    else
        exports['qb-target']:AddTargetEntity(entity, {
            options = options,
            distance = distance
        })
    end
end

local function ClearDeliveryWaypoint()
    if activeWaypoint and DoesBlipExist(activeWaypoint) then
        RemoveBlip(activeWaypoint)
        activeWaypoint = nil
    end
end

local function SetDeliveryWaypoint(coords)
    ClearDeliveryWaypoint()
    activeWaypoint = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(activeWaypoint, 1)
    SetBlipColour(activeWaypoint, 3)
    SetBlipRoute(activeWaypoint, true)
    SetBlipRouteColour(activeWaypoint, 3)
end

local function SetReturnWaypoint()
    ClearDeliveryWaypoint()
    activeWaypoint = AddBlipForCoord(Config.PedCoords.x, Config.PedCoords.y, Config.PedCoords.z)
    SetBlipSprite(activeWaypoint, 1)
    SetBlipColour(activeWaypoint, 3)
    SetBlipRoute(activeWaypoint, true)
    SetBlipRouteColour(activeWaypoint, 3)
end

-- Find the next uncompleted delivery and set waypoint to it
local function SetNextDeliveryWaypoint()
    if outOfPapers then
        -- If out of papers, always go back to NPC
        SetReturnWaypoint()
        return
    end
    
    -- Find first uncompleted delivery
    for k, v in pairs(myData.locations) do
        if not completedDeliveries[k] then
            SetDeliveryWaypoint(v)
            return
        end
    end
    
    -- If we get here, all deliveries are done
    SetReturnWaypoint()
    DoNotification('Route complete! Return to NPC to collect payment.', 'success')
end

local function resetJob()
    if next(workZones) then
        for i = 1, #workZones do
            if workZones[i] then
                workZones[i]:remove()
            end
        end
    end
    if next(blipStore) then
        for k, _ in pairs(blipStore) do
            if DoesBlipExist(blipStore[k]) then
                RemoveBlip(blipStore[k])
                blipStore[k] = nil
            end
        end
    end
    ClearDeliveryWaypoint()
    outOfPapers = false
    completedDeliveries = {}
    remainingCount = 0
    isValidatingDrop = false
    workZones = {}
    myData = {}
end

local function validateDrop(point)
    isValidatingDrop = true
    local success, num = lib.callback.await('randol_paperboy:server:validateDrop', 1500, point.coords, netid)
    if success then
        -- Mark this delivery as completed
        completedDeliveries[point.index] = true
        remainingCount = num
        
        -- Remove the zone
        point:remove()
        
        -- Remove the blip for this delivery
        if blipStore[point.index] and DoesBlipExist(blipStore[point.index]) then
            RemoveBlip(blipStore[point.index])
            blipStore[point.index] = nil
        end
        
        if num > 0 then
            DoNotification(('Paper delivered! %s remaining'):format(num), 'success')
            -- Set waypoint to next uncompleted delivery
            SetNextDeliveryWaypoint()
        else
            -- All done, go back to NPC
            SetReturnWaypoint()
            DoNotification('Route complete! Return to NPC to collect payment.', 'success')
        end
    end
    isValidatingDrop = false
    Wait(1000) 
    delay = false
end

local function createPaperRoute(netId)
    if clockedIn then return end

    local vehicle = lib.waitFor(function()
        if NetworkDoesEntityExistWithNetworkId(netId) then
            return NetToVeh(netId)
        end
    end, 'Could not load entity in time.', 5000)

    -- Keys are now given server-side immediately, no need to wait
    
    -- Reset tracking
    completedDeliveries = {}
    remainingCount = #myData.locations
    
    for k, v in pairs(myData.locations) do
        local zone = lib.points.new({ 
            coords = vec3(v.x, v.y, v.z), 
            distance = Config.DeliveryMarkerDistance,
            index = k, -- Store the original index for tracking
            nearby = function(point)
                -- Don't draw marker if already completed
                if completedDeliveries[point.index] then return end
                
                DrawMarker(
                    Config.MarkerType, 
                    point.coords.x, point.coords.y, point.coords.z + Config.MarkerHeight, 
                    0, 0, 0, 0, 0, 0, 
                    Config.MarkerSize.x, Config.MarkerSize.y, Config.MarkerSize.z, 
                    Config.MarkerColor.r, Config.MarkerColor.g, Config.MarkerColor.b, Config.MarkerColor.a, 
                    0, 0, 0, 0
                )
                
                if point.isClosest and not completedDeliveries[point.index] and IsProjectileTypeWithinDistance(point.coords.x, point.coords.y, point.coords.z, joaat(Config.PaperItemName), 3.0, true) and not delay then
                    delay = true
                    validateDrop(point)
                end
            end,
        })
        workZones[#workZones+1] = zone
        
        blipStore[k] = AddBlipForCoord(v.x, v.y, v.z)
        SetBlipSprite(blipStore[k], 40)
        SetBlipDisplay(blipStore[k], 4)
        SetBlipScale(blipStore[k], 0.65)
        SetBlipAsShortRange(blipStore[k], true)
        SetBlipColour(blipStore[k], 61)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName('Delivery')
        EndTextCommandSetBlipName(blipStore[k])
    end
    
    clockedIn = true
    
    -- Set waypoint to first delivery
    if myData.locations[1] then
        SetDeliveryWaypoint(myData.locations[1])
    end
    
    DoNotification(('Route started! Deliver %s newspapers.'):format(#myData.locations), 'success')
end

-- Function to find an available spawn point (returns index or nil if all blocked)
local function findAvailableSpawn()
    for index, spawn in ipairs(Config.BikeSpawns) do
        if not IsAnyVehicleNearPoint(spawn.x, spawn.y, spawn.z, Config.BikeSpawnCheckRadius) then
            return index
        end
    end
    return nil
end

RegisterNUICallback('close', function(data, cb)
    cb('ok')
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({action = 'hide'})
end)

RegisterNUICallback('startRoute', function(data, cb)
    cb('ok')
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({action = 'hide'})
    
    -- Find an available spawn point (client-side check)
    local spawnIndex = findAvailableSpawn()
    
    if not spawnIndex then
        DoNotification('All bike spawns are blocked.', 'error') 
        return 
    end
    
    -- Pass the spawn index to server so it knows which spawn to use
    myData, netid = lib.callback.await('randol_paperboy:server:beginWork', false, data.routeId, spawnIndex)
    if myData and netid then
        createPaperRoute(netid)
    end
end)

RegisterNUICallback('restockPapers', function(data, cb)
    cb('ok')
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({action = 'hide'})
    local success, newLevel = lib.callback.await('randol_paperboy:server:restockPapers', false)
    if success then
        outOfPapers = false
        -- Set waypoint to next uncompleted delivery
        SetNextDeliveryWaypoint()
    end
end)

RegisterNUICallback('completeJob', function(data, cb)
    cb('ok')
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({action = 'hide'})
    local success = lib.callback.await('randol_paperboy:server:clockOut', false)
    if success then
        clockedIn = false
        outOfPapers = false
        resetJob()
    end
end)

local function openPaperboyUI()
    local stats = lib.callback.await('randol_paperboy:server:getPlayerStats', false)
    if not stats then return end
    
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        data = stats,
        clockedIn = clockedIn,
        outOfPapers = outOfPapers
    })
end

local function spawnPed()
    if DoesEntityExist(startPed) then return end

    local model = joaat(Config.Ped)
    lib.requestModel(model, 5000)
    startPed = CreatePed(0, model, Config.PedCoords, false, false)

    SetEntityAsMissionEntity(startPed, true, true)
    SetPedFleeAttributes(startPed, 0, 0)
    SetBlockingOfNonTemporaryEvents(startPed, true)
    SetEntityInvincible(startPed, true)
    FreezeEntityPosition(startPed, true)
    SetPedDefaultComponentVariation(startPed)
    SetModelAsNoLongerNeeded(model)

    lib.requestAnimDict('timetable@ron@ig_3_couch')
    TaskPlayAnim(startPed, 'timetable@ron@ig_3_couch', 'base', 3.0, 3.0, -1, 01, 0, false, false, false)
    RemoveAnimDict('timetable@ron@ig_3_couch')

    addTargetEntity(startPed, {
        { 
            icon = 'fa-solid fa-newspaper',
            label = 'Open Paperboy Menu',
            action = function()
                openPaperboyUI()
            end,
        },
    }, 1.5)
end

local function yeetPed()
    if DoesEntityExist(startPed) then
        if GetResourceState('ox_target') == 'started' then
            exports.ox_target:removeLocalEntity(startPed, {'Open Paperboy Menu'})
        else
            exports['qb-target']:RemoveTargetEntity(startPed, {'Open Paperboy Menu'})
        end
        DeleteEntity(startPed)
        startPed = nil
    end
end

function createStartPoint()
    pedInteract = lib.points.new({
        coords = Config.PedCoords.xyz,
        distance = 30,
        onEnter = spawnPed,
        onExit = yeetPed,
    })
end

function OnPlayerLogout()
    resetJob() 
    yeetPed()
    if pedInteract then pedInteract:remove() end
end

RegisterNetEvent('randol_paperboy:client:jobCancelled', function()
    clockedIn = false
    outOfPapers = false
    resetJob()
    DoNotification('Your job has been cancelled.', 'error')
end)

AddEventHandler('onResourceStart', function(resource)
    if GetCurrentResourceName() ~= resource then return end
    Wait(1000)
    if LocalPlayer.state.isLoggedIn then
        createStartPoint()
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    createStartPoint()
end)

AddEventHandler('onResourceStop', function(resourceName) 
    if GetCurrentResourceName() == resourceName then
        OnPlayerLogout()
    end 
end)

AddEventHandler('ox_inventory:itemCount', function(item, count)
    if item == Config.PaperItemName and clockedIn and count == 0 then
        -- Skip if we're currently validating a drop (prevents race condition)
        if isValidatingDrop then return end
        
        -- Small delay to let validateDrop finish updating remainingCount
        Wait(100)
        
        -- Only trigger if there are still uncompleted deliveries
        if remainingCount > 0 and not isValidatingDrop then
            outOfPapers = true
            SetReturnWaypoint()
            DoNotification(('%s deliveries left but out of papers! Return to NPC to restock or finish.'):format(remainingCount), 'error')
        end
    end
end)
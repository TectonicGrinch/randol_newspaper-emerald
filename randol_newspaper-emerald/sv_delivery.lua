local Config = lib.require('shared')
local Server = lib.require('sv_config')
local workers = {}
local ox_inventory = exports.ox_inventory

-- ═══════════════════════════════════════════════════════════
--                    LOGGING FUNCTIONS
-- ═══════════════════════════════════════════════════════════

local function LogMinimal(message)
    if Config.LoggingLevel == 'minimal' or Config.LoggingLevel == 'debug' then
        print(('[^3Paperboy^7] %s'):format(message))
    end
end

local function LogDebug(message)
    if Config.LoggingLevel == 'debug' then
        print(('[^5Paperboy DEBUG^7] %s'):format(message))
    end
end

-- ═══════════════════════════════════════════════════════════
--                    HELPER FUNCTIONS
-- ═══════════════════════════════════════════════════════════

local function getPlayerIdentifier(src)
    local player = exports.qbx_core:GetPlayer(src)
    return player and player.PlayerData.citizenid or nil
end

local function getPlayerData(identifier)
    LogDebug(('Fetching player data for identifier: %s'):format(identifier))
    local result = MySQL.single.await('SELECT * FROM paperboy_data WHERE identifier = ?', {identifier})
    if not result then
        LogDebug(('No existing data found, creating new record for: %s'):format(identifier))
        MySQL.insert('INSERT INTO paperboy_data (identifier, character_name, level, exp, total_money, routes_completed, papers_missed, papers_delivered) VALUES (?, ?, 1, 0, 0, 0, 0, 0)', {identifier, 'Unknown'})
        return {identifier = identifier, character_name = 'Unknown', level = 1, exp = 0, total_money = 0, routes_completed = 0, papers_missed = 0, papers_delivered = 0}
    end
    LogDebug(('Found player data - Level: %s, EXP: %s'):format(result.level, result.exp))
    return result
end

local function updatePlayerData(identifier, data)
    LogDebug(('Updating player data - Level: %s, EXP: %s, Total Money: $%s'):format(data.level, data.exp, data.total_money))
    MySQL.update('UPDATE paperboy_data SET character_name = ?, level = ?, exp = ?, total_money = ?, routes_completed = ?, papers_missed = ?, papers_delivered = ? WHERE identifier = ?',
        {data.character_name, data.level, data.exp, data.total_money, data.routes_completed, data.papers_missed, data.papers_delivered, identifier})
end

local function getMaxExp()
    -- Get the highest level requirement and add the buffer
    local maxLevelExp = Config.LevelRequirements[#Config.LevelRequirements] or 0
    return maxLevelExp + Config.MaxExpBuffer
end

local function capExp(exp)
    local maxExp = getMaxExp()
    if exp > maxExp then
        LogDebug(('EXP capped from %s to %s'):format(exp, maxExp))
        return maxExp
    end
    return exp
end

local function calculateLevel(exp)
    local level = 1
    for lvl = #Config.LevelRequirements, 1, -1 do
        if exp >= Config.LevelRequirements[lvl] then
            level = lvl
            break
        end
    end
    return level
end

local function getVehicleDisplayName(model)
    return Config.VehicleDisplayNames[model] or model
end

local function createBicycle(source, level, spawnIndex)
    local vehicleModel = Config.VehiclePerLevel[level] or Config.BikeModel
    LogDebug(('Creating vehicle %s for player %s at spawn index %s'):format(vehicleModel, source, spawnIndex))
    
    -- Use the spawn index passed from client, or default to first spawn
    local spawnCoords = Config.BikeSpawns[spawnIndex] or Config.BikeSpawns[1]
    
    local veh = CreateVehicleServerSetter(joaat(vehicleModel), 'bike', spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnCoords.w)
    local ped = GetPlayerPed(source)

    while not DoesEntityExist(veh) do Wait(0) end 
    while GetVehiclePedIsIn(ped, false) ~= veh do TaskWarpPedIntoVehicle(ped, veh, -1) Wait(0) end

    -- Give keys immediately on server side for faster response
    local plate = GetVehicleNumberPlateText(veh)
    TriggerClientEvent('qb-vehiclekeys:client:AddKeys', source, plate)
    LogDebug(('Vehicle created with plate: %s'):format(plate))

    return NetworkGetNetworkIdFromEntity(veh)
end

lib.callback.register('randol_paperboy:server:getPlayerStats', function(source)
    local identifier = getPlayerIdentifier(source)
    if not identifier then return false end
    
    local data = getPlayerData(identifier)
    
    local player = GetPlayer(source)
    if player then
        local charName = player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname
        data.character_name = charName
        MySQL.update('UPDATE paperboy_data SET character_name = ? WHERE identifier = ?', {charName, identifier})
    end
    
    local nextLevelExp = data.exp
    if Config.LevelRequirements[data.level + 1] then
        nextLevelExp = Config.LevelRequirements[data.level + 1]
    end
    
    local availableRoutes = {}
    for i, area in ipairs(Server.Areas) do
        table.insert(availableRoutes, {
            id = i,
            name = area.Name,
            requiredLevel = area.RequiredLevel,
            locations = #area.Locations,
            payout = area.Payout,
            locked = data.level < area.RequiredLevel
        })
    end
    
    local leaderboard = MySQL.query.await('SELECT character_name, papers_delivered FROM paperboy_data ORDER BY papers_delivered DESC LIMIT 10', {})
    
    return {
        level = data.level,
        exp = data.exp,
        nextLevelExp = nextLevelExp,
        totalMoney = data.total_money,
        routesCompleted = data.routes_completed,
        papersMissed = data.papers_missed,
        papersDelivered = data.papers_delivered,
        routes = availableRoutes,
        currentVehicle = getVehicleDisplayName(Config.VehiclePerLevel[data.level] or Config.BikeModel),
        leaderboard = leaderboard or {}
    }
end)

lib.callback.register('randol_paperboy:server:beginWork', function(source, routeId, spawnIndex)
    if workers[source] then 
        LogDebug(('Player %s already has active work'):format(source))
        return false 
    end

    local src = source
    local identifier = getPlayerIdentifier(src)
    if not identifier then 
        LogDebug(('Could not get identifier for player %s'):format(src))
        return false 
    end
    
    local playerData = getPlayerData(identifier)
    
    if not Server.Areas[routeId] then 
        LogDebug(('Invalid route ID: %s'):format(routeId))
        return false 
    end
    if playerData.level < Server.Areas[routeId].RequiredLevel then
        DoNotification(src, 'You do not meet the level requirement for this route.', 'error')
        LogDebug(('Player %s does not meet level requirement for route %s'):format(src, routeId))
        return false
    end

    TriggerClientEvent('ox_inventory:disarm', src, true)

    local count = ox_inventory:GetItemCount(src, Config.PaperItemName)
    if count > 0 then
        ox_inventory:RemoveItem(src, Config.PaperItemName, count)
    end
    
    local generatedLocs = {}
    for i = 1, #Server.Areas[routeId].Locations do
        generatedLocs[#generatedLocs+1] = Server.Areas[routeId].Locations[i]
    end

    workers[src] = {
        locations = generatedLocs,
        payout = Server.Areas[routeId].Payout,
        totalPay = 0,
        entity = 0,
        totalLocations = #generatedLocs,
        papersDelivered = 0,
        restockCount = 0,
        requiredLevel = Server.Areas[routeId].RequiredLevel,
        identifier = identifier,
        routeName = Server.Areas[routeId].Name,
    }

    local amount = #workers[src].locations
    local netid = createBicycle(src, playerData.level, spawnIndex)
    workers[src].entity = NetworkGetEntityFromNetworkId(netid)
    ox_inventory:AddItem(src, Config.PaperItemName, amount)

    LogMinimal(('Player %s started route "%s" with %s deliveries'):format(src, Server.Areas[routeId].Name, amount))

    return workers[src], netid
end)

lib.callback.register('randol_paperboy:server:validateDrop', function(source, location, netid)
    if not workers[source] then 
        LogDebug(('validateDrop called but no active worker for player %s'):format(source))
        return false 
    end

    local src = source
    local pos = GetEntityCoords(GetPlayerPed(src))
    local isValid = false

    if #(pos - location.xyz) > Config.DeliveryValidationDistance then 
        LogDebug(('Player %s too far from delivery point'):format(src))
        return false 
    end

    for i = 1, #workers[src].locations do
        if workers[src].locations[i] == location then
            table.remove(workers[src].locations, i)
            isValid = true
            break
        end
    end

    if not isValid then 
        LogDebug(('Invalid delivery location for player %s'):format(src))
        return false 
    end

    workers[src].papersDelivered = workers[src].papersDelivered + 1
    local payout = math.random(workers[src].payout.min, workers[src].payout.max)

    if NetworkGetNetworkIdFromEntity(GetVehiclePedIsIn(GetPlayerPed(source))) ~= netid then
        payout = 1
        DoNotification(src, 'Wrong vehicle! Pay reduced to $1.', 'error')
        LogDebug(('Player %s delivered in wrong vehicle'):format(src))
    end

    workers[src].totalPay = workers[src].totalPay + payout
    DoNotification(src, ('+$%s (Total: $%s)'):format(payout, workers[src].totalPay), 'success')
    LogDebug(('Player %s delivered paper %s/%s - Payout: $%s'):format(src, workers[src].papersDelivered, workers[src].totalLocations, payout))

    return true, #workers[src].locations
end)

lib.callback.register('randol_paperboy:server:restockPapers', function(source)
    if not workers[source] then 
        DoNotification(source, 'You do not have an active delivery.', 'error')
        LogDebug(('restockPapers called but no active worker for player %s'):format(source))
        return false 
    end

    local src = source
    local identifier = workers[src].identifier
    local remaining = #workers[src].locations

    if remaining == 0 then
        DoNotification(src, 'You have no remaining deliveries.', 'error')
        return false
    end

    local playerData = getPlayerData(identifier)
    playerData.exp = math.max(0, playerData.exp - Config.ExpLossPerRestock)
    local newLevel = calculateLevel(playerData.exp)
    
    if newLevel < 1 then
        newLevel = 1
        playerData.exp = 0
    end
    
    playerData.level = newLevel
    updatePlayerData(identifier, playerData)
    
    workers[src].restockCount = workers[src].restockCount + 1
    LogDebug(('Player %s restocked papers (count: %s) - New EXP: %s, Level: %s'):format(src, workers[src].restockCount, playerData.exp, newLevel))

    if newLevel < workers[src].requiredLevel then
        DoNotification(src, 'You dropped below the required level for this route! Job cancelled.', 'error')
        LogMinimal(('Player %s dropped below required level - Job cancelled'):format(src))
        
        if DoesEntityExist(workers[src].entity) then DeleteEntity(workers[src].entity) end
        TriggerClientEvent('ox_inventory:disarm', src, true)
        local count = ox_inventory:GetItemCount(src, Config.PaperItemName)
        if count > 0 then
            ox_inventory:RemoveItem(src, Config.PaperItemName, count)
        end
        
        TriggerClientEvent('randol_paperboy:client:jobCancelled', src)
        workers[src] = nil
        return false
    end

    ox_inventory:AddItem(src, Config.PaperItemName, remaining)
    DoNotification(src, ('Restocked %s papers. -10 EXP (Level %s)'):format(remaining, newLevel), 'info')

    return true, newLevel
end)

lib.callback.register('randol_paperboy:server:clockOut', function(source)
    if not workers[source] then
        DoNotification(source, 'You do not have any active deliveries.', 'error')
        LogDebug(('clockOut called but no active worker for player %s'):format(source))
        return false 
    end

    local src = source
    local player = GetPlayer(src)
    local identifier = workers[src].identifier
    local playerData = getPlayerData(identifier)

    local papersDelivered = workers[src].papersDelivered
    local totalPapers = workers[src].totalLocations
    local papersNotDelivered = totalPapers - papersDelivered
    local completedAll = #workers[src].locations == 0
    local finalPay = workers[src].totalPay
    local expGained = 0
    local routeName = workers[src].routeName

    if not completedAll then
        local penaltyPercent = math.min(papersNotDelivered * Config.PenaltyPerPaper, Config.MaxPenalty)
        local penaltyAmount = math.floor(finalPay * (penaltyPercent / 100))
        finalPay = finalPay - penaltyAmount
        
        local expLoss = papersNotDelivered * Config.ExpPerPaper
        playerData.exp = math.max(0, playerData.exp - expLoss)
        playerData.level = calculateLevel(playerData.exp)
        
        if playerData.level < 1 then
            playerData.level = 1
            playerData.exp = 0
        end
        
        DoNotification(src, ('Route incomplete: -%s%% ($%s), -%s EXP'):format(penaltyPercent, penaltyAmount, expLoss), 'error')
        LogMinimal(('Player %s incomplete route "%s" - Delivered: %s/%s, Penalty: %s%%, Pay: $%s'):format(src, routeName, papersDelivered, totalPapers, penaltyPercent, finalPay))
        
        playerData.papers_missed = playerData.papers_missed + papersNotDelivered
        playerData.papers_delivered = playerData.papers_delivered + papersDelivered
    else
        finalPay = finalPay + Config.CompletionBonus
        
        expGained = papersDelivered * Config.ExpPerPaper
        
        -- Apply EXP with cap
        playerData.exp = capExp(playerData.exp + expGained)
        playerData.level = calculateLevel(playerData.exp)
        playerData.routes_completed = playerData.routes_completed + 1
        playerData.papers_delivered = playerData.papers_delivered + papersDelivered
        
        DoNotification(src, ('Complete! +$%s bonus, +%s EXP (Lvl %s)'):format(Config.CompletionBonus, expGained, playerData.level), 'success')
        LogMinimal(('Player %s completed route "%s" - Delivered: %s, Pay: $%s, EXP: %s (Total: %s)'):format(src, routeName, papersDelivered, finalPay, expGained, playerData.exp))
    end

    if finalPay > 0 then
        AddMoney(player, 'cash', finalPay)
        playerData.total_money = playerData.total_money + finalPay
        DoNotification(src, ('Payment received: $%s'):format(finalPay), 'success')
    else
        DoNotification(src, 'No payment due.', 'error')
    end

    updatePlayerData(identifier, playerData)

    if DoesEntityExist(workers[src].entity) then DeleteEntity(workers[src].entity) end

    TriggerClientEvent('ox_inventory:disarm', src, true)

    local count = ox_inventory:GetItemCount(src, Config.PaperItemName)
    
    if count > 0 then
        ox_inventory:RemoveItem(src, Config.PaperItemName, count)
    end

    workers[src] = nil
    return true
end)

function OnServerPlayerUnload(src)
    if workers[src] then
        LogDebug(('Player %s disconnected with active job - cleaning up'):format(src))
        if DoesEntityExist(workers[src].entity) then DeleteEntity(workers[src].entity) end
        workers[src] = nil
    end
end

local hookId = ox_inventory:registerHook('swapItems', function(payload)
    return false
end, {
    print = false,
    itemFilter = {
        [Config.PaperItemName] = true,
    },
    inventoryFilter = {
        '^glove[%w]+',
        '^trunk[%w]+',
        '^drop-[%w]+',
        '^newdrop$'
    }
})

AddEventHandler("onResourceStop", function(resource)
    if resource == GetCurrentResourceName() then
        exports.ox_inventory:removeHooks(hookId)
    end
end)
---@type WeedSharedConfig
local sharedConfig = require 'config.shared'
---@type WeedServerConfig
local config = require 'config.server'

---@type table<number, vector3>
local outsidePlants = {}

---@param property string
---@return WeedPlant[]
lib.callback.register('qbx_weed:server:getPropertyPlants', function(_, property)
    if sharedConfig.plantsSpawnType == 'outside' then return {} end

    local propertyPlants = {}
    local plants = MySQL.query.await('SELECT * FROM weed_plants WHERE property = ?', { property })

    for i = 1, #plants, 1 do
        local plant = plants[i]
        plant.coords = json.decode(plant.coords)
        plant.coords = vec3(plant.coords.x, plant.coords.y, plant.coords.z)
        propertyPlants[#propertyPlants + 1] = plant
    end

    return propertyPlants
end)

---@param ids number[]
---@return WeedPlant[]
lib.callback.register('qbx_weed:server:getOutsidePlants', function(_, ids)
    if sharedConfig.plantsSpawnType == 'property' then return {} end

    local plants = {}
    for i = 1, #ids do
        local plant = MySQL.prepare.await('SELECT * FROM weed_plants WHERE id = ?', { ids[i] })
        if plant then
            plant.coords = json.decode(plant.coords)
            plant.coords = vec3(plant.coords.x, plant.coords.y, plant.coords.z)
            plants[#plants + 1] = plant
        end
    end

    return plants
end)

---@param coords vector3
---@param sort string
---@param property? string
RegisterNetEvent('qbx_weed:server:placePlant', function(coords, sort, property)
    if (property and sharedConfig.plantsSpawnType == 'outside') or (not property and sharedConfig.plantsSpawnType == 'property') then return end

    local gender = math.random(1, 2) == 1 and 'female' or 'male'
    if property then
        MySQL.insert.await('INSERT INTO weed_plants (property, coords, gender, sort) VALUES (?, ?, ?, ?)', { property, json.encode(coords), gender, sort })
        TriggerClientEvent('qbx_weed:client:refreshPropertyPlants', -1, property)
    else
        local id = MySQL.insert.await('INSERT INTO weed_plants (coords, gender, sort) VALUES (?, ?, ?)', { json.encode(coords), gender, sort })
        outsidePlants[id] = coords
    end
end)

---@param property? string
---@param plantId integer
---@param plantCoords vector3
RegisterNetEvent('qbx_weed:server:removeDeadPlant', function(property, plantId, plantCoords)
    if (property and sharedConfig.plantsSpawnType == 'outside') or (not property and sharedConfig.plantsSpawnType == 'property') then return end

    local player = exports.qbx_core:GetPlayer(source)
    if not player or player.PlayerData.metadata.currentPropertyId ~= property or #(GetEntityCoords(GetPlayerPed(player.PlayerData.source)) - plantCoords) > 2 then return end

    MySQL.prepare.await('DELETE FROM weed_plants WHERE id = ?', { plantId })
    if property then
        TriggerClientEvent('qbx_weed:client:refreshPropertyPlants', -1, property)
    else
        outsidePlants[plantId] = nil
    end
end)

---@param plant WeedPlant
local function checkPlantFood(plant)
    if plant.food >= 50 then
        MySQL.update.await('UPDATE weed_plants SET food = ? WHERE id = ?', { plant.food - 1, plant.id })
        if plant.health + 1 < 100 then
            MySQL.update.await('UPDATE weed_plants SET health = ? WHERE id = ?', { plant.health + 1, plant.id })
        end
    else
        if plant.food - 1 >= 0 then
            MySQL.update('UPDATE weed_plants SET food = ? WHERE id = ?', { plant.food - 1, plant.id })
        end

        if plant.health - 1 >= 0 then
            MySQL.update.await('UPDATE weed_plants SET health = ? WHERE id = ?', { plant.health - 1, plant.id })
        end
    end
end

---@param plant WeedPlant
local function growPlant(plant)
    if plant.health <= 50 then return end

    local grow = math.random(config.randomGrowAmount.min, config.randomGrowAmount.max)
    if plant.stageProgress + grow < 100 then
        MySQL.update.await('UPDATE weed_plants SET stageProgress = ? WHERE id = ?', { plant.stageProgress + grow, plant.id })
        return
    end

    if plant.stage == #sharedConfig.plants[plant.sort].stages then return end

    MySQL.update.await('UPDATE weed_plants SET stage = ? WHERE id = ?', { plant.stage + 1, plant.id })
    MySQL.update.await('UPDATE weed_plants SET stageProgress = ? WHERE id = ?', { 0, plant.id })
end

---@param itemSlot integer
---@param seed string
RegisterNetEvent('qbx_weed:server:removeSeed', function(itemSlot, seed)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return end

    exports.ox_inventory:RemoveItem(player.PlayerData.source, seed, 1, nil, itemSlot)
end)

---@param property? string
---@param seedAmount integer
---@param plantItemName string
---@param plantId integer
---@param plantCoords vector3
RegisterNetEvent('qbx_weed:server:harvestPlant', function(property, seedAmount, plantItemName, plantId, plantCoords)
    if (property and sharedConfig.plantsSpawnType == 'outside') or (not property and sharedConfig.plantsSpawnType == 'property') then return end

    local player = exports.qbx_core:GetPlayer(source)
    if not player or player.PlayerData.metadata.currentPropertyId ~= property or #(GetEntityCoords(GetPlayerPed(player.PlayerData.source)) - plantCoords) > 2 then return end

    if not MySQL.prepare.await('SELECT 1 FROM weed_plants WHERE id = ?', { plantId }) then
        exports.qbx_core:Notify(player.PlayerData.source, locale('error.this_plant_no_longer_exists'), 'error')
        return
    end

    local weedBag = exports.ox_inventory:Search(player.PlayerData.source, 'count', sharedConfig.items.emptyBag)
    local harvestAmount = math.random(config.randomHarvestAmount.min, config.randomHarvestAmount.max)
    if weedBag < harvestAmount then
        exports.qbx_core:Notify(player.PlayerData.source, locale('error.you_dont_have_enough_resealable_bags'), 'error')
        return
    end

    if not exports.ox_inventory:RemoveItem(player.PlayerData.source, sharedConfig.items.emptyBag, harvestAmount) then return end

    exports.ox_inventory:AddItem(player.PlayerData.source, plantItemName .. '_seed', seedAmount)
    exports.ox_inventory:AddItem(player.PlayerData.source, plantItemName, harvestAmount)
    MySQL.prepare.await('DELETE FROM weed_plants WHERE id = ?', { plantId })
    exports.qbx_core:Notify(player.PlayerData.source, locale('text.the_plant_has_been_harvested'), 'success')

    if property then
        TriggerClientEvent('qbx_weed:client:refreshPropertyPlants', -1, property)
    else
        outsidePlants[plantId] = nil
    end
end)

---@param property string
---@param amount integer
---@param plantName string
---@param plantId integer
RegisterNetEvent('qbx_weed:server:foodPlant', function(property, amount, plantName, plantId)
    if (property and sharedConfig.plantsSpawnType == 'outside') or (not property and sharedConfig.plantsSpawnType == 'property') then return end

    local player = exports.qbx_core:GetPlayer(source)
    if not player then return end

    local plantFood = MySQL.prepare.await('SELECT food FROM weed_plants WHERE id = ?', { plantId })
    exports.qbx_core:Notify(player.PlayerData.source, ('%s | %s %s%% + %s%% (%s%%)'):format(sharedConfig.plants[plantName].label, locale('text.nutrition'), plantFood, amount, plantFood + amount), 'inform')

    local newAmount = plantFood + amount
    if newAmount > 100 then
        MySQL.update.await('UPDATE weed_plants SET food = ? WHERE id = ?', { 100, plantId })
    else
        MySQL.update.await('UPDATE weed_plants SET food = ? WHERE id = ?', { newAmount, plantId })
    end

    exports.ox_inventory:RemoveItem(player.PlayerData.source, sharedConfig.items.nutrition, 1)

    if property then
        TriggerClientEvent('qbx_weed:client:refreshPropertyPlants', -1, property)
    else
        TriggerClientEvent('qbx_weed:client:refreshOutsidePlants', -1, outsidePlants)
    end
end)

AddEventHandler('qbx_core:server:onSetMetaData', function(meta, _, value, source)
    if meta ~= 'currentPropertyId' or value then return end

    TriggerClientEvent('qbx_weed:client:refreshOutsidePlants', source, outsidePlants)
end)

CreateThread(function()
    if sharedConfig.plantsSpawnType == 'property' then return end

    local plants = MySQL.query.await('SELECT * FROM weed_plants WHERE property IS NULL')
    for i = 1, #plants do
        local plant = plants[i]
        plant.coords = json.decode(plant.coords)
        plant.coords = vec3(plant.coords.x, plant.coords.y, plant.coords.z)
        outsidePlants[plant.id] = plant.coords
    end

    local sleep = config.outsidePlantsRefreshInterval * 1000
    while true do
        TriggerClientEvent('qbx_weed:client:refreshOutsidePlants', -1, outsidePlants)

        Wait(sleep)
    end
end)

CreateThread(function()
    local sleep = config.plantFoodCheckInterval * 1000
    while true do
        local plants = MySQL.query.await('SELECT id, food, health FROM weed_plants')
        for i = 1, #plants do
            checkPlantFood(plants[i])
        end

        TriggerClientEvent('qbx_weed:client:refreshPlantStats', -1)

        Wait(sleep)
    end
end)

CreateThread(function()
    local sleep = config.plantGrowInterval * 1000
    while true do
        local plants = MySQL.query.await('SELECT id, stage, sort, health, stageProgress FROM weed_plants')
        for i = 1, #plants do
            growPlant(plants[i])
        end

        TriggerClientEvent('qbx_weed:client:refreshPlantStats', -1)

        Wait(sleep)
    end
end)

---@type WeedSharedConfig
local sharedConfig = require 'config.shared'
---@type WeedServerConfig
local config = require 'config.server'
local clientConfig = require 'config.client'

---@type table<number, vector3>
local outsidePlants = {}
local plantLocks = {}

local function isValidContext(player, property)
    if property ~= nil and type(property) ~= 'string' then return false end
    if (property and sharedConfig.plantsSpawnType == 'outside') or (not property and sharedConfig.plantsSpawnType == 'property') then return false end
    local currentProperty = player.PlayerData.metadata.currentPropertyId
    return (currentProperty and tostring(currentProperty) or nil) == property
end

local function getPlant(source, property, plantId)
    if math.type(plantId) ~= 'integer' then return end

    local player = exports.qbx_core:GetPlayer(source)
    if not player or not isValidContext(player, property) then return end

    local plant = MySQL.single.await('SELECT * FROM weed_plants WHERE id = ?', {plantId})
    if not plant or plant.property ~= property then return end
    local currentPlayer = exports.qbx_core:GetPlayer(source)
    if not currentPlayer or currentPlayer.PlayerData.citizenid ~= player.PlayerData.citizenid
        or not isValidContext(currentPlayer, property) then return end

    local coords = json.decode(plant.coords)
    if not coords then return end
    plant.coords = vec3(coords.x, coords.y, coords.z)
    local ped = GetPlayerPed(source)
    if ped == 0 or #(GetEntityCoords(ped) - plant.coords) > 3.0 then return end
    return player, plant
end

---@param property string
---@return WeedPlant[]
lib.callback.register('qbx_weed:server:getPropertyPlants', function(source, property)
    if sharedConfig.plantsSpawnType == 'outside' then return {} end

    local player = exports.qbx_core:GetPlayer(source)
    if not player or type(property) ~= 'string' or not isValidContext(player, property) then return {} end

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
lib.callback.register('qbx_weed:server:getOutsidePlants', function(source, ids)
    if sharedConfig.plantsSpawnType == 'property' then return {} end
    if type(ids) ~= 'table' or #ids > 100 then return {} end

    local plants = {}
    local ped = GetPlayerPed(source)
    if ped == 0 then return plants end
    local playerCoords = GetEntityCoords(ped)
    for i = 1, #ids do
        local id = ids[i]
        local knownCoords = math.type(id) == 'integer' and outsidePlants[id]
        if knownCoords and #(playerCoords - knownCoords) <= clientConfig.outsidePlantsDistance + 10.0 then
            local plant = MySQL.prepare.await('SELECT * FROM weed_plants WHERE id = ? AND property IS NULL', {id})
            if plant then
                plant.coords = json.decode(plant.coords)
                plant.coords = vec3(plant.coords.x, plant.coords.y, plant.coords.z)
                plants[#plants + 1] = plant
            end
        end
    end

    return plants
end)

---@param coords vector3
---@param sort string
---@param property? string
---@param itemSlot integer
---@param seed string
RegisterNetEvent('qbx_weed:server:placePlant', function(coords, sort, property, itemSlot, seed)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    local plantConfig = type(sort) == 'string' and sharedConfig.plants[sort]
    if not player or not plantConfig or not isValidContext(player, property) then return end
    if math.type(itemSlot) ~= 'integer' or seed ~= plantConfig.item .. '_seed' then return end

    local item = exports.ox_inventory:GetSlot(src, itemSlot)
    if not item or item.name ~= seed then return end

    if type(coords) ~= 'table' and type(coords) ~= 'vector3' then return end
    local x = tonumber(coords.x or coords[1])
    local y = tonumber(coords.y or coords[2])
    local z = tonumber(coords.z or coords[3])
    if not x or not y or not z or x ~= x or y ~= y or z ~= z then return end
    coords = vec3(x, y, z)
    if #(GetEntityCoords(GetPlayerPed(src)) - coords) > 2.0 then return end
    if not exports.ox_inventory:RemoveItem(src, seed, 1, nil, itemSlot) then return end

    local gender = math.random(1, 2) == 1 and 'female' or 'male'
    if property then
        local id = MySQL.insert.await('INSERT INTO weed_plants (property, coords, gender, sort) VALUES (?, ?, ?, ?)', { property, json.encode(coords), gender, sort })
        if not id then
            exports.ox_inventory:AddItem(src, seed, 1)
            return
        end
        TriggerClientEvent('qbx_weed:client:refreshPropertyPlants', -1, property)
    else
        local id = MySQL.insert.await('INSERT INTO weed_plants (coords, gender, sort) VALUES (?, ?, ?)', { json.encode(coords), gender, sort })
        if not id then
            exports.ox_inventory:AddItem(src, seed, 1)
            return
        end
        outsidePlants[id] = coords
    end
end)

---@param property? string
---@param plantId integer
RegisterNetEvent('qbx_weed:server:removeDeadPlant', function(property, plantId)
    local src = source
    if plantLocks[plantId] then return end
    local player, plant = getPlant(src, property, plantId)
    if not player or plant.health > 0 or plantLocks[plantId] then return end

    plantLocks[plantId] = true
    local deleted = MySQL.update.await('DELETE FROM weed_plants WHERE id = ? AND health <= 0', {plantId})
    plantLocks[plantId] = nil
    if deleted ~= 1 then return end
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

---@param property? string
---@param plantId integer
RegisterNetEvent('qbx_weed:server:harvestPlant', function(property, plantId)
    local src = source
    if plantLocks[plantId] then return end
    local player, plant = getPlant(src, property, plantId)
    if not player or plantLocks[plantId] then return end

    local plantConfig = sharedConfig.plants[plant.sort]
    if not plantConfig or plant.health <= 0 or plant.stage < #plantConfig.stages then return end
    plantLocks[plantId] = true

    local weedBag = exports.ox_inventory:Search(src, 'count', sharedConfig.items.emptyBag)
    local harvestAmount = math.random(config.randomHarvestAmount.min, config.randomHarvestAmount.max)
    if weedBag < harvestAmount then
        plantLocks[plantId] = nil
        exports.qbx_core:Notify(src, locale('error.you_dont_have_enough_resealable_bags'), 'error')
        return
    end

    if not exports.ox_inventory:RemoveItem(src, sharedConfig.items.emptyBag, harvestAmount) then
        plantLocks[plantId] = nil
        return
    end

    local deleted = MySQL.update.await('DELETE FROM weed_plants WHERE id = ?', {plantId})
    plantLocks[plantId] = nil
    if deleted ~= 1 then
        exports.ox_inventory:AddItem(src, sharedConfig.items.emptyBag, harvestAmount)
        return
    end

    local seedAmount = plant.gender == 'male' and math.random(1, 2) or math.random(1, 6)
    exports.ox_inventory:AddItem(src, plantConfig.item .. '_seed', seedAmount)
    exports.ox_inventory:AddItem(src, plantConfig.item, harvestAmount)
    exports.qbx_core:Notify(src, locale('text.the_plant_has_been_harvested'), 'success')

    if property then
        TriggerClientEvent('qbx_weed:client:refreshPropertyPlants', -1, property)
    else
        outsidePlants[plantId] = nil
    end
end)

---@param property string
---@param plantId integer
RegisterNetEvent('qbx_weed:server:foodPlant', function(property, plantId)
    local src = source
    if plantLocks[plantId] then return end
    local player, plant = getPlant(src, property, plantId)
    if not player or plant.food >= 100 or not sharedConfig.plants[plant.sort] or plantLocks[plantId] then return end

    plantLocks[plantId] = true
    if not exports.ox_inventory:RemoveItem(src, sharedConfig.items.nutrition, 1) then
        plantLocks[plantId] = nil
        return
    end
    local amount = math.random(40, 60)
    local newAmount = math.min(100, plant.food + amount)
    MySQL.update.await('UPDATE weed_plants SET food = ? WHERE id = ?', {newAmount, plantId})
    plantLocks[plantId] = nil
    exports.qbx_core:Notify(src, ('%s | %s %s%% + %s%% (%s%%)'):format(sharedConfig.plants[plant.sort].label, locale('text.nutrition'), plant.food, amount, newAmount), 'inform')

    if property then
        TriggerClientEvent('qbx_weed:client:refreshPropertyPlants', -1, property)
    else
        TriggerClientEvent('qbx_weed:client:refreshOutsidePlants', -1, outsidePlants)
    end
end)

for sort, plantConfig in pairs(sharedConfig.plants) do
    exports.qbx_core:CreateUseableItem(plantConfig.item .. '_seed', function(source, item)
        TriggerClientEvent('qbx_weed:client:placePlant', source, sort, item)
    end)
end

exports.qbx_core:CreateUseableItem(sharedConfig.items.nutrition, function(source)
    TriggerClientEvent('qbx_weed:client:foodPlant', source)
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

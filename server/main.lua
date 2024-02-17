local sharedConfig = require 'config.shared'

lib.callback.register('qbx_weed:server:getBuildingPlants', function(_, building)
    local buildingPlants = {}
    local plants = MySQL.query.await('SELECT * FROM house_plants WHERE building = ?', { building })

    for i = 1, #plants, 1 do
        local plant = plants[i]
        plant.coords = json.decode(plant.coords)
        plant.coords = vec3(plant.coords.x, plant.coords.y, plant.coords.z)
        buildingPlants[#buildingPlants + 1] = plant
    end

    return buildingPlants
end)

RegisterNetEvent('qbx_weed:server:placePlant', function(coords, sort, currentHouse)
    local gender = math.random(1, 2) == 1 and 'female' or 'male'
    MySQL.insert.await('INSERT INTO house_plants (building, coords, gender, sort) VALUES (?, ?, ?, ?)', { currentHouse, json.encode(coords), gender, sort })
    TriggerClientEvent('qbx_weed:client:refreshHousePlants', -1, currentHouse)
end)

RegisterNetEvent('qbx_weed:server:removeDeathPlant', function(building, plantId, plantCoords)
    local player = exports.qbx_core:GetPlayer(source)
    if not player or not building then return end
    if #(GetEntityCoords(GetPlayerPed(player.PlayerData.source)) - plantCoords) > 2 then return end
    MySQL.prepare.await('DELETE FROM house_plants WHERE id = ?', { plantId })
    TriggerClientEvent('qbx_weed:client:refreshHousePlants', -1, building)
end)

---@param plant table
local function checkHousePlantFood(plant)
    if plant.food >= 50 then
        MySQL.update.await('UPDATE house_plants SET food = ? WHERE id = ?', { plant.food - 1, plant.id })
        if plant.health + 1 < 100 then
            MySQL.update.await('UPDATE house_plants SET health = ? WHERE id = ?', { plant.health + 1, plant.id })
        end
    end

    if plant.food < 50 then
        if plant.food - 1 >= 0 then
            MySQL.update('UPDATE house_plants SET food = ? WHERE id = ?', { plant.food - 1, plant.id })
        end
        if plant.health - 1 >= 0 then
            MySQL.update.await('UPDATE house_plants SET health = ? WHERE id = ?', { plant.health - 1, plant.id })
        end
    end
end

local function manageHousePlants()
    while true do
        local housePlants = MySQL.query.await('SELECT id, food, health FROM house_plants')
        for i = 1, #housePlants do
            checkHousePlantFood(housePlants[i])
        end
        TriggerClientEvent('qbx_weed:client:refreshPlantStats', -1)
        Wait(60 * 1000 * 19.2)
    end
end

---@param plantStage string
---@return string nextStage
local function getNextStage(plantStage)
    local initStage = tonumber(string.sub(plantStage, -1))
    return 'stage' .. tostring(initStage + 1)
end

---@param plant table
local function growPlant(plant)
    if plant.health <= 50 then return end
    local grow = math.random(1, 3)
    if plant.progress + grow < 100 then
        MySQL.update.await('UPDATE house_plants SET progress = ? WHERE id = ?', { (plant.progress + grow), plant.id })
        return
    end
    if plant.stage == sharedConfig.plants[plant.sort].highestStage then return end
    if plant.stage then
        MySQL.update.await('UPDATE house_plants SET stage = ? WHERE id = ?', { getNextStage(plant.stage), plant.id })
    end
    MySQL.update.await('UPDATE house_plants SET progress = ? WHERE id = ?', { 0, plant.id })
end

local function updatePlantGrowth()
    while true do
        local housePlants = MySQL.query.await('SELECT id, stage, sort, health, progress FROM house_plants')
        for i = 1, #housePlants do
            growPlant(housePlants[i])
        end
        TriggerClientEvent('qbx_weed:client:refreshPlantStats', -1)
        Wait(60 * 1000 * 9.6)
    end
end

CreateThread(manageHousePlants)
CreateThread(updatePlantGrowth)

for plantName, plantData in pairs(sharedConfig.plants) do
    exports.qbx_core:CreateUseableItem(plantData.item .. '_seed', function(source, item)
        TriggerClientEvent('qbx_weed:client:placePlant', source, plantName, item)
    end)
end

exports.qbx_core:CreateUseableItem(sharedConfig.items.nutrition, function(source, item)
    TriggerClientEvent('qbx_weed:client:foodPlant', source, item)
end)

RegisterServerEvent('qbx_weed:server:removeSeed', function(itemslot, seed)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return end

    player.Functions.RemoveItem(seed, 1, itemslot)
end)

RegisterNetEvent('qbx_weed:server:harvestPlant', function(house, seedAmount, plantItemName, plantId, plantCoords)
    local player = exports.qbx_core:GetPlayer(source)
    if not player or not house then return end
    if #(GetEntityCoords(GetPlayerPed(player.PlayerData.source)) - plantCoords) > 2 then return end
    if not MySQL.prepare.await('SELECT 1 FROM house_plants WHERE id = ?', { plantId }) then
        exports.qbx_core:Notify(player.PlayerData.source, locale('error.this_plant_no_longer_exists'), 'error' )
        return
    end

    local weedBag = player.Functions.GetItemByName(sharedConfig.items.emptyBag)
    local harvestAmount = math.random(12, 16)

    if not weedBag or weedBag.amount < harvestAmount then
        exports.qbx_core:Notify(player.PlayerData.source, locale('error.you_dont_have_enough_resealable_bags'), 'error')
        return
    end

    if player.Functions.RemoveItem(sharedConfig.items.emptyBag, harvestAmount) then
        player.Functions.AddItem(plantItemName .. '_seed', seedAmount)
        player.Functions.AddItem(plantItemName, harvestAmount)
        MySQL.prepare.await('DELETE FROM house_plants WHERE id = ?', { plantId })
        exports.qbx_core:Notify(player.PlayerData.source, locale('text.the_plant_has_been_harvested'), 'success')
        TriggerClientEvent('qbx_weed:client:refreshHousePlants', -1, house)
    end
end)

RegisterNetEvent('qbx_weed:server:foodPlant', function(house, amount, plantName, plantId)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return end
    local plantFood = MySQL.prepare.await('SELECT food FROM house_plants WHERE id = ?', { plantId })
    exports.qbx_core:Notify(player.PlayerData.source, sharedConfig.plants[plantName].label .. ' | Nutrition: ' .. plantFood .. '% + ' .. amount .. '% (' .. (plantFood + amount) .. '%)', 'inform')
    if plantFood + amount > 100 then
        MySQL.update.await('UPDATE house_plants SET food = ? WHERE id = ?', { 100, plantId })
    else
        MySQL.update.await('UPDATE house_plants SET food = ? WHERE id = ?', { (plantFood + amount), plantId })
    end
    player.Functions.RemoveItem(sharedConfig.items.nutrition, 1)
    TriggerClientEvent('qbx_weed:client:refreshHousePlants', -1, house)
end)
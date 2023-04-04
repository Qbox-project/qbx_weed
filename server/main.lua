local QBCore = exports['qbx-core']:GetCoreObject()

QBCore.Functions.CreateCallback('qb-weed:server:getBuildingPlants', function(_, cb, building)
    local buildingPlants = {}

    MySQL.query('SELECT * FROM house_plants WHERE building = ?', { building }, function(plants)
        for i = 1, #plants, 1 do
            buildingPlants[#buildingPlants + 1] = plants[i]
        end

        if buildingPlants then
            cb(buildingPlants)
        else
            cb(nil)
        end
    end)
end)

RegisterNetEvent('qb-weed:server:placePlant', function(coords, sort, currentHouse)
    local random = math.random(1, 2)
    local gender = "woman"
    if random == 1 then
        gender = "man"
    end
    MySQL.insert('INSERT INTO house_plants (building, coords, gender, sort, plantid) VALUES (?, ?, ?, ?, ?)', { currentHouse, coords, gender, sort, math.random(111111, 999999) })
    TriggerClientEvent('qb-weed:client:refreshHousePlants', -1, currentHouse)
end)

RegisterNetEvent('qb-weed:server:removeDeathPlant', function(building, plantId)
    MySQL.query('DELETE FROM house_plants WHERE plantid = ? AND building = ?', { plantId, building })
    TriggerClientEvent('qb-weed:client:refreshHousePlants', -1, building)
end)

---@param plants table
local function checkHousePlantFood(plants)
    if plants.food >= 50 then
        MySQL.update('UPDATE house_plants SET food = ? WHERE plantid = ?', { (plants.food - 1), plants.plantid })
        if plants.health + 1 < 100 then
            MySQL.update('UPDATE house_plants SET health = ? WHERE plantid = ?', { (plants.health + 1), plants.plantid })
        end
    end

    if plants.food < 50 then
        if plants.food - 1 >= 0 then
            MySQL.update('UPDATE house_plants SET food = ? WHERE plantid = ?', { (plants.food - 1), plants.plantid })
        end
        if plants.health - 1 >= 0 then
            MySQL.update('UPDATE house_plants SET health = ? WHERE plantid = ?', { (plants.health - 1), plants.plantid })
        end
    end
end

local function manageHousePlants()
    while true do
        local housePlants = MySQL.query.await('SELECT * FROM house_plants', {})
        for i=1, #housePlants do
            checkHousePlantFood(housePlants[i])
        end
        TriggerClientEvent('qb-weed:client:refreshPlantStats', -1)
        Wait((60 * 1000) * 19.2)
    end
end

---@param plants table
---@return string nextStage
local function getNextStage(plant)
    local initStage = tonumber(string.sub(plant.stage, -1))
    return "stage-" .. tostring(initStage + 1)
end

---@param plants table
local function growPlant(plant)
    if plant.health <= 50 then return end
    local grow = math.random(1, 3)
    if plant.progress + grow < 100 then
        MySQL.update('UPDATE house_plants SET progress = ? WHERE plantid = ?', { (plant.progress + grow), plant.plantid })
        return
    end
    if plant.stage == QBWeed.Plants[plant.sort]["highestStage"] then return end
    if plant.stage then
        MySQL.update('UPDATE house_plants SET stage = ? WHERE plantid = ?', { getNextStage(plant.stage), plant.plantid })
    end
    MySQL.update('UPDATE house_plants SET progress = ? WHERE plantid = ?', { 0, plant.plantid })
end

local function updatePlantGrowth()
    while true do
        local housePlants = MySQL.query.await('SELECT * FROM house_plants', {})
        for i=1, #housePlants do
            growPlant(housePlants[i])
        end
        TriggerClientEvent('qb-weed:client:refreshPlantStats', -1)
        Wait((60 * 1000) * 9.6)
    end
end

CreateThread(manageHousePlants)
CreateThread(updatePlantGrowth)

QBCore.Functions.CreateUseableItem("weed_white-widow_seed", function(source, item)
    TriggerClientEvent('qb-weed:client:placePlant', source, 'white-widow', item)
end)

QBCore.Functions.CreateUseableItem("weed_skunk_seed", function(source, item)
    TriggerClientEvent('qb-weed:client:placePlant', source, 'skunk', item)
end)

QBCore.Functions.CreateUseableItem("weed_purple-haze_seed", function(source, item)
    TriggerClientEvent('qb-weed:client:placePlant', source, 'purple-haze', item)
end)

QBCore.Functions.CreateUseableItem("weed_og-kush_seed", function(source, item)
    TriggerClientEvent('qb-weed:client:placePlant', source, 'og-kush', item)
end)

QBCore.Functions.CreateUseableItem("weed_amnesia_seed", function(source, item)
    TriggerClientEvent('qb-weed:client:placePlant', source, 'amnesia', item)
end)

QBCore.Functions.CreateUseableItem("weed_ak47_seed", function(source, item)
    TriggerClientEvent('qb-weed:client:placePlant', source, 'ak47', item)
end)

QBCore.Functions.CreateUseableItem("weed_nutrition", function(source, item)
    TriggerClientEvent('qb-weed:client:foodPlant', source, item)
end)

RegisterServerEvent('qb-weed:server:removeSeed', function(itemslot, seed)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    player.Functions.RemoveItem(seed, 1, itemslot)
end)

RegisterNetEvent('qb-weed:server:harvestPlant', function(house, amount, plantName, plantId)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    local weedBag = player.Functions.GetItemByName('empty_weed_bag')
    local sndAmount = math.random(12, 16)

    if not weedBag or weedBag.amount < sndAmount then 
        TriggerClientEvent('ox_lib:notify', src, { description = Lang:t('error.you_dont_have_enough_resealable_bags'), type = 'error' })
        return
    end

    if not house then
        TriggerClientEvent('ox_lib:notify', src, { description = Lang:t('error.house_not_found'), type = 'error' })
        return
    end

    local result = MySQL.query.await('SELECT * FROM house_plants WHERE plantid = ? AND building = ?', { plantId, house })
    
    if result[1] then
        TriggerClientEvent('ox_lib:notify', src, { description = Lang:t('error.this_plant_no_longer_exists'), type = 'error' })
        MySQL.Async.execute('UPDATE players SET inventory = ? WHERE citizenid = ?', { json.encode({}), player.PlayerData.citizenid })
        return
    end
    
    player.Functions.AddItem('weed_' .. plantName .. '_seed', amount)
    player.Functions.AddItem('weed_' .. plantName, sndAmount)
    player.Functions.RemoveItem('empty_weed_bag', sndAmount)
    MySQL.query('DELETE FROM house_plants WHERE plantid = ? AND building = ?', { plantId, house })
    TriggerClientEvent('QBCore:Notify', src, Lang:t('text.the_plant_has_been_harvested'), 'success', 3500)
    TriggerClientEvent('ox_lib:notify', src, { description = Lang:t('text.the_plant_has_been_harvested'), type = 'success' })
    TriggerClientEvent('qb-weed:client:refreshHousePlants', -1, house)
end)

RegisterNetEvent('qb-weed:server:foodPlant', function(house, amount, plantName, plantId)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    local plantStats = MySQL.query.await('SELECT * FROM house_plants WHERE building = ? AND sort = ? AND plantid = ?', { house, plantName, tostring(plantId) })
    TriggerClientEvent('ox_lib:notify', src, { description = QBWeed.Plants[plantName]["label"] .. ' | Nutrition: ' .. plantStats[1].food .. '% + ' .. amount .. '% (' .. (plantStats[1].food + amount) .. '%)', type = 'inform' })
    if plantStats[1].food + amount > 100 then
        MySQL.update('UPDATE house_plants SET food = ? WHERE building = ? AND plantid = ?', { 100, house, plantId })
    else
        MySQL.update('UPDATE house_plants SET food = ? WHERE building = ? AND plantid = ?', { (plantStats[1].food + amount), house, plantId })
    end
    player.Functions.RemoveItem('weed_nutrition', 1)
    TriggerClientEvent('qb-weed:client:refreshHousePlants', -1, house)
end)

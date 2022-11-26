local QBCore = exports['qb-core']:GetCoreObject()

QBCore.Functions.CreateCallback('qb-weed:server:getBuildingPlants', function(_, cb, building)
    local buildingPlants = {}

    MySQL.query('SELECT * FROM house_plants WHERE building = ?', { building }, function(plants)
        for i = 1, #plants, 1 do
            buildingPlants[#buildingPlants + 1] = plants[i]
        end

        if buildingPlants ~= nil then
            cb(buildingPlants)
        else
            cb(nil)
        end
    end)
end)

RegisterNetEvent('qb-weed:server:placePlant', function(coords, sort, currentHouse)
    local random = math.random(1, 2)
    local gender

    if random == 1 then
        gender = "man"
    else
        gender = "woman"
    end

    MySQL.insert('INSERT INTO house_plants (building, coords, gender, sort, plantid) VALUES (?, ?, ?, ?, ?)', {
        currentHouse,
        coords,
        gender,
        sort,
        math.random(111111, 999999)
    })

    TriggerClientEvent('qb-weed:client:refreshHousePlants', -1, currentHouse)
end)

RegisterNetEvent('qb-weed:server:removeDeathPlant', function(building, plantId)
    MySQL.query('DELETE FROM house_plants WHERE plantid = ? AND building = ?', {
        plantId, building
    })

    TriggerClientEvent('qb-weed:client:refreshHousePlants', -1, building)
end)

CreateThread(function()
    while true do
        local housePlants = MySQL.query.await('SELECT * FROM house_plants')

        for k, _ in pairs(housePlants) do
            if housePlants[k].food >= 50 then
                MySQL.update('UPDATE house_plants SET food = ? WHERE plantid = ?', { (housePlants[k].food - 1), housePlants[k].plantid })

                if housePlants[k].health + 1 < 100 then
                    MySQL.update('UPDATE house_plants SET health = ? WHERE plantid = ?', { (housePlants[k].health + 1), housePlants[k].plantid })
                end
            end

            if housePlants[k].food < 50 then
                if housePlants[k].food - 1 >= 0 then
                    MySQL.update('UPDATE house_plants SET food = ? WHERE plantid = ?', { (housePlants[k].food - 1), housePlants[k].plantid })
                end

                if housePlants[k].health - 1 >= 0 then
                    MySQL.update('UPDATE house_plants SET health = ? WHERE plantid = ?', { (housePlants[k].health - 1), housePlants[k].plantid })
                end
            end
        end

        TriggerClientEvent('qb-weed:client:refreshPlantStats', -1)

        Wait((60 * 1000) * 19.2)
    end
end)

CreateThread(function()
    while true do
        local housePlants = MySQL.query.await('SELECT * FROM house_plants')

        for k, _ in pairs(housePlants) do
            if housePlants[k].health > 50 then
                local Grow = math.random(1, 3)

                if housePlants[k].progress + Grow < 100 then
                    MySQL.update('UPDATE house_plants SET progress = ? WHERE plantid = ?', { (housePlants[k].progress + Grow), housePlants[k].plantid })
                elseif housePlants[k].progress + Grow >= 100 then
                    if housePlants[k].stage ~= Config.Plants[housePlants[k].sort]["highestStage"] then
                        if housePlants[k].stage == "stage-a" then
                            MySQL.update('UPDATE house_plants SET stage = ? WHERE plantid = ?', { 'stage-b', housePlants[k].plantid })
                        elseif housePlants[k].stage == "stage-b" then
                            MySQL.update('UPDATE house_plants SET stage = ? WHERE plantid = ?', { 'stage-c', housePlants[k].plantid })
                        elseif housePlants[k].stage == "stage-c" then
                            MySQL.update('UPDATE house_plants SET stage = ? WHERE plantid = ?', { 'stage-d', housePlants[k].plantid })
                        elseif housePlants[k].stage == "stage-d" then
                            MySQL.update('UPDATE house_plants SET stage = ? WHERE plantid = ?', { 'stage-e', housePlants[k].plantid })
                        elseif housePlants[k].stage == "stage-e" then
                            MySQL.update('UPDATE house_plants SET stage = ? WHERE plantid = ?', { 'stage-f', housePlants[k].plantid })
                        elseif housePlants[k].stage == "stage-f" then
                            MySQL.update('UPDATE house_plants SET stage = ? WHERE plantid = ?', { 'stage-g', housePlants[k].plantid })
                        end

                        MySQL.update('UPDATE house_plants SET progress = ? WHERE plantid = ?', { 0, housePlants[k].plantid })
                    end
                end
            end
        end

        TriggerClientEvent('qb-weed:client:refreshPlantStats', -1)

        Wait((60 * 1000) * 9.6)
    end
end)

for k, v in pairs(Config.Plants) do
    QBCore.Functions.CreateUseableItem('weed_' .. v.item .. '_seed', function(source, item)
        TriggerClientEvent('qb-weed:client:placePlant', source, k, item)
    end)
end

QBCore.Functions.CreateUseableItem("weed_nutrition", function(source, item)
    TriggerClientEvent('qb-weed:client:foodPlant', source, item)
end)

RegisterNetEvent('qb-weed:server:removeSeed', function(itemslot, seed)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    Player.Functions.RemoveItem(seed, 1, itemslot)
end)

RegisterNetEvent('qb-weed:server:harvestPlant', function(house, amount, plantName, plantId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local weedBag = Player.Functions.GetItemByName('empty_weed_bag')
    local sndAmount = math.random(12, 16)

    if weedBag ~= nil then
        if weedBag.amount >= sndAmount then
            if house ~= nil then
                local result = MySQL.query.await('SELECT * FROM house_plants WHERE plantid = ? AND building = ?', {
                    plantId,
                    house
                })

                if result[1] ~= nil then
                    Player.Functions.AddItem('weed_' .. plantName .. '_seed', amount)
                    Player.Functions.AddItem('weed_' .. plantName, sndAmount)
                    Player.Functions.RemoveItem('empty_weed_bag', sndAmount)

                    MySQL.query('DELETE FROM house_plants WHERE plantid = ? AND building = ?', {
                        plantId,
                        house
                    })

                    TriggerClientEvent('QBCore:Notify', src, Lang:t('text.the_plant_has_been_harvested'), 'success', 3500)
                    TriggerClientEvent('ox_lib:notify', src, { description = Lang:t('text.the_plant_has_been_harvested'), type = 'success' })
                    TriggerClientEvent('qb-weed:client:refreshHousePlants', -1, house)
                else
                    TriggerClientEvent('ox_lib:notify', src, {
                        description = Lang:t('error.this_plant_no_longer_exists'),
                        type = 'error'
                    })

                    MySQL.update('UPDATE players SET inventory = ? WHERE citizenid = ?', {
                        json.encode({}),
                        Player.PlayerData.citizenid
                    })
                end
            else
                TriggerClientEvent('ox_lib:notify', src, {
                    description = Lang:t('error.house_not_found'),
                    type = 'error'
                })
            end
        else
            TriggerClientEvent('ox_lib:notify', src, {
                description = Lang:t('error.you_dont_have_enough_resealable_bags'),
                type = 'error'
            })
        end
    else
        TriggerClientEvent('ox_lib:notify', src, {
            description = Lang:t('error.you_dont_have_enough_resealable_bags'),
            type = 'error'
        })
    end
end)

RegisterNetEvent('qb-weed:server:foodPlant', function(house, amount, plantName, plantId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local plantStats = MySQL.single.await('SELECT * FROM house_plants WHERE building = ? AND sort = ? AND plantid = ?', {
        house,
        plantName,
        tostring(plantId)
    })

    TriggerClientEvent('ox_lib:notify', src, {
        description = Config.Plants[plantName].label .. ' | Nutrition: ' .. plantStats.food .. '% + ' .. amount .. '% (' .. (plantStats.food + amount) .. '%)',
        type = 'inform'
    })

    if plantStats.food + amount > 100 then
        MySQL.update('UPDATE house_plants SET food = ? WHERE building = ? AND plantid = ?', {
            100,
            house,
            plantId
        })
    else
        MySQL.update('UPDATE house_plants SET food = ? WHERE building = ? AND plantid = ?', {
            plantStats.food + amount,
            house,
            plantId
        })
    end

    Player.Functions.RemoveItem('weed_nutrition', 1)

    TriggerClientEvent('qb-weed:client:refreshHousePlants', -1, house)
end)
local sharedConfig = require 'config.shared'
local housePlants = {}
local insideHouse = false
local currentHouse = nil
local plantsSpawned = false
local closestTarget = 0

local function spawnPlants()
    if plantsSpawned then return end
    for _, v in pairs(housePlants[currentHouse]) do
        local plantProp = CreateObject(joaat(sharedConfig.plants[v.sort].stages[v.stage]), v.coords.x, v.coords.y, v.coords.z, false, false, false)
        while not plantProp do Wait(0) end

        PlaceObjectOnGroundProperly(plantProp)
        Wait(10)
        FreezeEntityPosition(plantProp, true)
        SetEntityAsMissionEntity(plantProp, false, false)
    end
    plantsSpawned = true
end

local function deleteClosestPlant(plantStage, plantData)
    if not (plantStage and plantData) then return end

    local closestPlant = GetClosestObjectOfType(plantData.coords.x, plantData.coords.y, plantData.coords.z, 3.5, joaat(plantStage), false, false, false)
    if closestPlant == 0 then return end

    DeleteObject(closestPlant)
end

local function despawnPlants()
    if not (plantsSpawned or currentHouse) then return end

    local plants = housePlants[currentHouse]

    for i = #plants, 1, -1 do
        local plantData = plants[i]
        for _, stage in pairs(sharedConfig.plants[plantData.sort].stages) do
            deleteClosestPlant(stage, plantData)
        end
        table.remove(plants, i)
    end

    plantsSpawned = false
end

local function updatePlantStats()
    if not (insideHouse or plantsSpawned) then return end
    for k, v in pairs(housePlants[currentHouse]) do
        local gender = v.gender == 'female' and 'F' or 'M'
        local plyDistance = #(GetEntityCoords(cache.ped) - v.coords)

        if plyDistance < 0.8 then
            closestTarget = k
            if v.health > 0 then
                if v.stage ~= sharedConfig.plants[v.sort].highestStage then
                    local label = ('%s%s~w~ [%s] | %s ~b~%s~w~ | %s ~b~%s~w~'):format(locale('text.sort'), sharedConfig.plants[v.sort].label, gender, locale('text.nutrition'), v.food, locale('text.health'), v.health)
                    qbx.drawText3d({text = label, coords = v.coords})
                else
                    local label = ('%s ~g~%s~w~ [%s] | %s ~b~%s~w~ | %s ~b~%s~w~'):format(locale('text.sort'), sharedConfig.plants[v.sort].label, gender, locale('text.nutrition'), v.food, locale('text.health'), v.health)
                    qbx.drawText3d({text = locale('text.harvest_plant'), coords = vec3(v.coords.x, v.coords.y, v.coords.z + 0.2)})
                    qbx.drawText3d({text = label, coords = v.coords})
                    if IsControlJustPressed(0, 38) then
                        if lib.progressCircle({
                            duration = 8000,
                            position = 'bottom',
                            label = locale('text.harvesting_plant'),
                            useWhileDead = false,
                            canCancel = true,
                            disable = {
                                move = true,
                                car = true,
                                mouse = false,
                                combat = true,
                            },
                            anim = {
                                dict = 'amb@world_human_gardener_plant@male@base',
                                clip = 'base',
                            },
                        })
                        then
                            ClearPedTasks(cache.ped)
                            local amount = math.random(1, 6)
                            if gender == 'M' then
                                amount = math.random(1, 2)
                            end
                            TriggerServerEvent('qbx_weed:server:harvestPlant', currentHouse, amount, sharedConfig.plants[v.sort].item, v.id, v.coords)
                        else
                            ClearPedTasks(cache.ped)
                            exports.qbx_core:Notify(locale('error.process_canceled'), 'error')
                        end
                    end
                end
            elseif v.health == 0 then
                qbx.drawText3d({text = locale('error.plant_has_died'), coords = v.coords})
                if IsControlJustPressed(0, 38) then
                    if lib.progressCircle({
                            duration = 8000,
                            position = 'bottom',
                            label = locale('text.removing_the_plant'),
                            useWhileDead = false,
                            canCancel = true,
                            disable = {
                                move = true,
                                car = true,
                                mouse = false,
                                combat = true,
                            },
                            anim = {
                                dict = 'amb@world_human_gardener_plant@male@base',
                                clip = 'base',
                            },
                        })
                    then
                        ClearPedTasks(cache.ped)
                        TriggerServerEvent('qbx_weed:server:removeDeathPlant', currentHouse, v.id, v.coords)
                    else
                        ClearPedTasks(cache.ped)
                        exports.qbx_core:Notify(locale('error.process_canceled'), 'error')
                    end
                end
            end
        end
    end
end

local function updatePlants()
    local sleep = 0
    while true do
        Wait(sleep)
        sleep = 0
        updatePlantStats()
        if not insideHouse then
            sleep = 5000
        end
    end
end

CreateThread(updatePlants)

RegisterNetEvent('qb-weed:client:getHousePlants', function(house)
    local plants = lib.callback.await('qbx_weed:server:getBuildingPlants', false, house)
    currentHouse = house
    housePlants[currentHouse] = plants
    insideHouse = true
    spawnPlants()
end)

RegisterNetEvent('qb-weed:client:leaveHouse', function()
    despawnPlants()
    Wait(1000)
    if not currentHouse then return end
    insideHouse = false
    housePlants[currentHouse] = nil
    currentHouse = nil
end)

RegisterNetEvent('qbx_weed:client:refreshHousePlants', function(house)
    if not currentHouse or currentHouse ~= house then return end
    despawnPlants()
    Wait(1000)
    local plants = lib.callback.await('qbx_weed:server:getBuildingPlants', false, house)
    currentHouse = house
    housePlants[currentHouse] = plants
    spawnPlants()
end)

RegisterNetEvent('qbx_weed:client:refreshPlantStats', function()
    if not insideHouse or not currentHouse then return end
    despawnPlants()
    Wait(1000)
    local plants = lib.callback.await('qbx_weed:server:getBuildingPlants', false, currentHouse)
    housePlants[currentHouse] = plants
    spawnPlants()
end)

RegisterNetEvent('qbx_weed:client:placePlant', function(type, item)
    local plyCoords = GetOffsetFromEntityInWorldCoords(cache.ped, 0, 0.75, 0)
    local closestPlant = 0
    for _, v in pairs(sharedConfig.props) do
        if closestPlant == 0 then
            closestPlant = GetClosestObjectOfType(plyCoords.x, plyCoords.y, plyCoords.z, 0.8, joaat(v), false, false, false)
        end
    end

    if currentHouse then
        if closestPlant == 0 then
            LocalPlayer.state:set('invBusy', true, true)
            if lib.progressCircle({
                duration = 8000,
                position = 'bottom',
                label = locale('text.planting'),
                useWhileDead = false,
                canCancel = true,
                disable = {
                    move = true,
                    car = true,
                    mouse = false,
                    combat = true,
                },
                anim = {
                    dict = 'amb@world_human_gardener_plant@male@base',
                    clip = 'base',
                },
            })
            then
                ClearPedTasks(cache.ped)
                TriggerServerEvent('qbx_weed:server:placePlant', plyCoords, type, currentHouse)
                TriggerServerEvent('qbx_weed:server:removeSeed', item.slot, item.name)
            else
                ClearPedTasks(cache.ped)
                exports.qbx_core:Notify(locale('error.process_canceled'), 'error')
                LocalPlayer.state:set('invBusy', false, true)
            end
        else
            exports.qbx_core:Notify(locale('error.cant_place_here'), 'error')
        end
    else
        exports.qbx_core:Notify(locale('error.not_safe_here'), 'error')
    end
end)

RegisterNetEvent('qbx_weed:client:foodPlant', function()
    if not currentHouse then return end

    if closestTarget ~= 0 then
        exports.qbx_core:Notify(locale('error.not_safe_here'), 'error')
        return
    end

    local data = housePlants[currentHouse][closestTarget]
    local plyDistance = #(GetEntityCoords(cache.ped) - data.coords)

    if plyDistance >= 1.0 then
        exports.qbx_core:Notify(locale('error.cant_place_here'), 'error')
        return
    end

    if data.food == 100 then
        exports.qbx_core:Notify(locale('error.not_need_nutrition'), 'error')
        return
    end

    LocalPlayer.state:set('invBusy', true, true)
    if lib.progressCircle({
            duration = math.random(4000, 8000),
            position = 'bottom',
            label = locale('text.feeding_plant'),
            useWhileDead = false,
            canCancel = true,
            disable = {
                move = true,
                car = true,
                mouse = false,
                combat = true,
            },
            anim = {
                dict = 'timetable@gardener@filling_can',
                clip = 'gar_ig_5_filling_can',
            },
        })
    then
        ClearPedTasks(cache.ped)
        local newFood = math.random(40, 60)
        TriggerServerEvent('qbx_weed:server:foodPlant', currentHouse, newFood, data.sort, data.id)
    else
        ClearPedTasks(cache.ped)
        LocalPlayer.state:set('invBusy', false, true)
        exports.qbx_core:Notify(locale('error.process_canceled'), 'error')
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    despawnPlants()
end)
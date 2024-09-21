---@type WeedSharedConfig
local sharedConfig = require 'config.shared'
---@type WeedClientConfig
local config = require 'config.client'
---@type table<string, WeedPlant[]>
local propertyPlants = {}
---@type WeedPlant[]
local outsidePlants = {}
local currentProperty = exports.qbx_core:GetPlayerData()?.metadata?.currentPropertyId
local plantsSpawned = false
local closestTarget = 0

currentProperty = currentProperty and tostring(currentProperty) or nil

local function spawnPropertyPlants()
    if plantsSpawned or not currentProperty then return end

    for i = 1, #propertyPlants[currentProperty] do
        local plant = propertyPlants[currentProperty][i]
        local plantProp = CreateObject(joaat(sharedConfig.plants[plant.sort].stages[plant.stage]), plant.coords.x, plant.coords.y, plant.coords.z, false, false, false)
        while not plantProp do
            Wait(0)
        end

        PlaceObjectOnGroundProperly(plantProp)
        Wait(10)
        FreezeEntityPosition(plantProp, true)
        SetEntityAsMissionEntity(plantProp, false, false)
    end

    plantsSpawned = true
end

local function spawnOutsidePlants()
    if plantsSpawned or currentProperty then return end

    for i = 1, #outsidePlants do
        local plant = outsidePlants[i]
        local plantProp = CreateObject(joaat(sharedConfig.plants[plant.sort].stages[plant.stage]), plant.coords.x, plant.coords.y, plant.coords.z, false, false, false)
        while not plantProp do
            Wait(0)
        end

        PlaceObjectOnGroundProperly(plantProp)
        Wait(10)
        FreezeEntityPosition(plantProp, true)
        SetEntityAsMissionEntity(plantProp, false, false)
    end

    plantsSpawned = true
end

---@param plantStage 1 | 2 | 3 | 4 | 5 | 6 | 7
---@param plantData WeedPlant
local function deleteClosestPlant(plantStage, plantData)
    if not plantStage or not plantData then return end

    local closestPlant = GetClosestObjectOfType(plantData.coords.x, plantData.coords.y, plantData.coords.z, 3.5, joaat(sharedConfig.plants[plantData.sort].stages[plantStage]), false, false, false)
    if closestPlant == 0 then return end

    DeleteObject(closestPlant)
end

---@param property string
local function despawnPropertyPlants(property)
    if not plantsSpawned or not property or not propertyPlants[property] then return end

    for i = 1, #propertyPlants[property] do
        local plantData = propertyPlants[property][i]
        for stage = 1, #sharedConfig.plants[plantData.sort].stages do
            deleteClosestPlant(stage, plantData)
        end
    end

    propertyPlants[property] = {}
    plantsSpawned = false
end

---@param property string
local function despawnOutsidePlants(property)
    if not plantsSpawned or property then return end

    for i = 1, #outsidePlants do
        local plantData = outsidePlants[i]
        for stage = 1, #sharedConfig.plants[plantData.sort].stages do
            deleteClosestPlant(stage, plantData)
        end
    end

    outsidePlants = {}
    plantsSpawned = false
end

local function updatePlantStats()
    if not plantsSpawned then return 1000 end

    local tbl = currentProperty and propertyPlants[currentProperty] or outsidePlants
    local sleep = 1000
    for i = 1, #tbl do
        local plant = tbl[i]
        local gender = plant.gender == 'female' and 'F' or 'M'
        local plyDistance = #(GetEntityCoords(cache.ped) - plant.coords)
        if plyDistance < 0.8 then
            closestTarget = i
            if plant.health > 0 then
                sleep = 0
                if plant.stage ~= #sharedConfig.plants[plant.sort].stages then
                    local label = ('%s%s~w~ [%s] | %s ~b~%s~w~ | %s ~b~%s~w~'):format(locale('text.sort'), sharedConfig.plants[plant.sort].label, gender, locale('text.nutrition'), plant.food, locale('text.health'), plant.health)
                    qbx.drawText3d({text = label, coords = plant.coords})
                else
                    local label = ('%s ~g~%s~w~ [%s] | %s ~b~%s~w~ | %s ~b~%s~w~'):format(locale('text.sort'), sharedConfig.plants[plant.sort].label, gender, locale('text.nutrition'), plant.food, locale('text.health'), plant.health)
                    qbx.drawText3d({text = locale('text.harvest_plant'), coords = vec3(plant.coords.x, plant.coords.y, plant.coords.z + 0.2)})
                    qbx.drawText3d({text = label, coords = plant.coords})
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
                            local amount = gender == 'M' and math.random(1, 2) or math.random(1, 6)
                            TriggerServerEvent('qbx_weed:server:harvestPlant', currentProperty, amount, sharedConfig.plants[plant.sort].item, plant.id, plant.coords)
                        else
                            exports.qbx_core:Notify(locale('error.process_canceled'), 'error')
                        end

                        ClearPedTasks(cache.ped)
                    end
                end
            elseif plant.health == 0 then
                sleep = 0
                qbx.drawText3d({text = locale('error.plant_has_died'), coords = plant.coords})
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
                        TriggerServerEvent('qbx_weed:server:removeDeadPlant', currentProperty, plant.id, plant.coords)
                    else
                        exports.qbx_core:Notify(locale('error.process_canceled'), 'error')
                    end

                    ClearPedTasks(cache.ped)
                end
            end
        end
    end

    return sleep
end

exports('placePlant', function(type, item)
    local plyCoords = GetOffsetFromEntityInWorldCoords(cache.ped, 0, 0.75, 0)
    local closestPlant = 0
    for i = 1, #sharedConfig.stageProps do
        if closestPlant == 0 then
            closestPlant = GetClosestObjectOfType(plyCoords.x, plyCoords.y, plyCoords.z, 0.8, joaat(sharedConfig.stageProps[i]), false, false, false)
        end
    end

    if closestPlant ~= 0 then
        return exports.qbx_core:Notify(locale('error.cant_place_here'), 'error')
    end

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
        TriggerServerEvent('qbx_weed:server:placePlant', plyCoords, type, currentProperty)
        TriggerServerEvent('qbx_weed:server:removeSeed', item.slot, item.name)
    else
        exports.qbx_core:Notify(locale('error.process_canceled'), 'error')
    end

    ClearPedTasks(cache.ped)
end)

exports('foodPlant', function()
    if closestTarget == 0 then
        return exports.qbx_core:Notify(locale('error.not_safe_here'), 'error')
    end

    local data = currentProperty and propertyPlants[currentProperty][closestTarget] or outsidePlants[closestTarget]
    local plyDistance = #(GetEntityCoords(cache.ped) - data.coords)
    if plyDistance >= 1.0 then
        return exports.qbx_core:Notify(locale('error.cant_place_here'), 'error')
    end

    if data.food == 100 then
        return exports.qbx_core:Notify(locale('error.not_need_nutrition'), 'error')
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
        local newFood = math.random(40, 60)
        TriggerServerEvent('qbx_weed:server:foodPlant', currentProperty, newFood, data.sort, data.id)
    else
        exports.qbx_core:Notify(locale('error.process_canceled'), 'error')
    end

    ClearPedTasks(cache.ped)
end)

RegisterNetEvent('qbx_core:client:onSetMetaData', function(meta, oldValue, value)
    if meta ~= 'currentPropertyId' then return end

    currentProperty = value and tostring(value) or nil

    if currentProperty then
        despawnOutsidePlants(oldValue)

        Wait(1000)

        local plants = lib.callback.await('qbx_weed:server:getPropertyPlants', false, currentProperty)
        propertyPlants[currentProperty] = plants
        spawnPropertyPlants()
    else
        despawnPropertyPlants(oldValue)

        Wait(1000)

        propertyPlants[oldValue] = nil

        Wait(2000) -- Wait for server to send outsidePlants

        spawnOutsidePlants()
    end
end)

RegisterNetEvent('qbx_weed:client:refreshPropertyPlants', function(property)
    if not currentProperty or currentProperty ~= property then return end

    despawnPropertyPlants(currentProperty)
    despawnOutsidePlants(currentProperty)

    Wait(1000)

    local plants = lib.callback.await('qbx_weed:server:getPropertyPlants', false, property)
    propertyPlants[currentProperty] = plants
    spawnPropertyPlants()
end)

RegisterNetEvent('qbx_weed:client:refreshPlantStats', function()
    despawnPropertyPlants(currentProperty)
    despawnOutsidePlants(currentProperty)

    Wait(1000)

    if currentProperty then
        local plants = lib.callback.await('qbx_weed:server:getPropertyPlants', false, currentProperty)
        propertyPlants[currentProperty] = plants
        spawnPropertyPlants()
    else
        spawnOutsidePlants()
    end
end)

---@param plants table<number, vector3>
RegisterNetEvent('qbx_weed:client:refreshOutsidePlants', function(plants)
    if source == '' or GetInvokingResource() then return end

    if currentProperty then
        if table.type(outsidePlants) ~= 'empty' then
            despawnOutsidePlants(currentProperty)
        end

        return
    end

    despawnOutsidePlants(currentProperty)

    Wait(1000)

    local closePlants = {}
    local playerCoords = GetEntityCoords(cache.ped)
    for k, v in pairs(plants) do
        if #(playerCoords - v) < config.outsidePlantsDistance then
            closePlants[#closePlants + 1] = k
        end
    end

    outsidePlants = lib.callback.await('qbx_weed:server:getOutsidePlants', false, closePlants)
    spawnOutsidePlants()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    despawnPropertyPlants(currentProperty)
    despawnOutsidePlants(currentProperty)
end)

CreateThread(function()
    while true do
        Wait(updatePlantStats())
    end
end)

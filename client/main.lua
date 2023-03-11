local QBCore = exports['qb-core']:GetCoreObject()
local housePlants = {}
local insideHouse = false
local currentHouse = nil
local plantsSpawned = false

local function DrawText3D(x, y, z, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x, y, z, 0)
    DrawText(0.0, 0.0)
    local factor = (string.len(text)) / 370
    DrawRect(0.0, 0.0 + 0.0125, 0.017 + factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end

local function spawnPlants()
    if plantsSpawned then return end
    for _, v in pairs(housePlants[currentHouse]) do
        local plantProp = CreateObject(joaat(QBWeed.Plants[v.sort].stages[v.stage]), v.coords.x, v.coords.y, v.coords.z, false, false, false)
        while not plantProp do Wait(0) end

        PlaceObjectOnGroundProperly(plantProp)
        Wait(10)
        FreezeEntityPosition(plantProp, true)
        SetEntityAsMissionEntity(plantProp, false, false)
    end
    plantsSpawned = true
end

local function deleteClosestPlant(plantStage, plantData)
    local closestPlant = GetClosestObjectOfType(plantData.coords.x, plantData.coords.y, plantData.coords.z, 3.5, joaat(plantStage), false, false, false)
    if closestPlant == 0 then return end

    DeleteObject(closestPlant)
end

local function despawnPlants()
    if not (plantsSpawned or currentHouse) then return end

    for _, v in pairs(housePlants[currentHouse]) do
        for _, stage in pairs(QBWeed.Plants[v.sort].stages) do
            deleteClosestPlant(stage, v)
            v = nil
        end
    end
    plantsSpawned = false
end

local function updatePlantStats()
    if not (insideHouse or plantsSpawned) then return end
    local ped = PlayerPedId()
    for _, v in pairs(housePlants[currentHouse]) do
        local gender = "M"
        if v.gender == "woman" then gender = "F" end

        local plyDistance = #(GetEntityCoords(ped) - v.coords)

        if plyDistance < 0.8 then
            if v.health > 0 then
                if v.stage ~= QBWeed.Plants[v.sort].highestStage then
                    DrawText3D(v.coords.x, v.coords.y, v.coords.z,('%s%s~w~ [%s] | %s ~b~%s% ~w~ | %s ~b~%s%'):format(Lang:t('text.sort'), QBWeed.Plants[v.sort].label, gender, Lang:t('text.nutrition'), v.food, Lang:t('text.health'), v.health))
                else
                    DrawText3D(v.coords.x, v.coords.y, v.coords.z + 0.2, Lang:t('text.harvest_plant'))
                    DrawText3D(v.coords.x, v.coords.y, v.coords.z, ('%s ~g~%s~w~ [%s] | %s ~b~%s% ~w~ | %s ~b~%s%'):format(Lang:t('text.sort'), QBWeed.Plants[v.sort].label, gender, Lang:t('text.nutrition'), v.food, Lang:t('text.health'), v.health))
                    if IsControlJustPressed(0, 38) then
                        if lib.progressCircle({
                                duration = 8000,
                                position = 'bottom',
                                label = Lang:t('text.harvesting_plant'),
                                useWhileDead = false,
                                canCancel = true,
                                disable = {
                                    move = true,
                                    car = true,
                                    mouse = false,
                                    combat = true,
                                },
                                anim = {
                                    dict = "amb@world_human_gardener_plant@male@base",
                                    clip = "base",
                                },
                            })
                        then
                            ClearPedTasks(ped)
                            local amount = math.random(1, 6)
                            if gender == "M" then
                                amount = math.random(1, 2)
                            end
                            TriggerServerEvent('qb-weed:server:harvestPlant', currentHouse, amount, v.sort, v.plantid)
                        else
                            ClearPedTasks(ped)
                            lib.notify({ description = Lang:t("error.process_canceled"), type = 'error' })
                        end
                    end
                end
            elseif v.health == 0 then
                DrawText3D(v.coords.x, v.coords.y, v.coords.z, Lang:t('error.plant_has_died'))
                if IsControlJustPressed(0, 38) then
                    if lib.progressCircle({
                            duration = 8000,
                            position = 'bottom',
                            label = Lang:t('text.removing_the_plant'),
                            useWhileDead = false,
                            canCancel = true,
                            disable = {
                                move = true,
                                car = true,
                                mouse = false,
                                combat = true,
                            },
                            anim = {
                                dict = "amb@world_human_gardener_plant@male@base",
                                clip = "base",
                            },
                        })
                    then
                        ClearPedTasks(ped)
                        TriggerServerEvent('qb-weed:server:removeDeathPlant', currentHouse, v.plantid)
                    else
                        ClearPedTasks(ped)
                        lib.notify({ description = Lang:t("error.process_canceled"), type = 'error' })
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
    QBCore.Functions.TriggerCallback('qb-weed:server:getBuildingPlants', function(plants)
        currentHouse = house
        housePlants[currentHouse] = plants
        insideHouse = true
        spawnPlants()
    end, house)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    despawnPlants()
end)

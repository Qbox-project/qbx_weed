---@type WeedServerConfig
return {
    randomGrowAmount = { -- Random amount of progress to give on interval when growing a plant with its health above 50
        min = 1,
        max = 3
    },
    randomHarvestAmount = { -- The random amount of weed to give for a harvest
        min = 12,
        max = 16
    },
    plantFoodCheckInterval = 1152, -- How much seconds it takes for the plant food to be checked. Default 1152 seconds (19.2 minutes)
    plantGrowInterval = 576, -- How much seconds it takes for the plant to grow. Default 576 seconds (9.6 minutes)
    outsidePlantsRefreshInterval = 25, -- The amount of seconds it takes to refresh outside plants. Default 25 seconds
}

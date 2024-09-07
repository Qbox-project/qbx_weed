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
    plantFoodCheckInterval = 1152000, -- How much milliseconds it takes for the plant food to be checked. Default 1152000 milliseconds (19.2 minutes)
    plantGrowInterval = 576000, -- How much milliseconds it takes for the plant to grow. Default 576000 milliseconds (9.6 minutes)
    outsidePlantsRefreshInterval = 25000, -- The amount of milliseconds it takes to refresh outside plants. Default 25000 milliseconds (25 seconds)
}

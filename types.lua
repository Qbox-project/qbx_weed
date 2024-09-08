---@meta

---@class WeedPlant
---@field id integer
---@field property? string
---@field stage 1 | 2 | 3 | 4 | 5 | 6 | 7
---@field sort string
---@field gender 'male' | 'female'
---@field food integer
---@field health integer
---@field stageProgress integer
---@field coords vector3

---@class WeedClientConfig
---@field outsidePlantsDistance number

---@class WeedServerConfig
---@field randomGrowAmount { min: number, max: number }
---@field randomHarvestAmount { min: number, max: number }
---@field plantFoodCheckInterval integer
---@field plantGrowInterval integer
---@field outsidePlantsRefreshInterval integer

---@class WeedSharedConfig
---@field plantsSpawnType 'property' | 'outside' | 'both'
---@field plants table<string, WeedSort>
---@field stageProps string[]
---@field items { nutrition: string, emptyBag: string }

---@class WeedSort
---@field label string
---@field item string
---@field stages string[]

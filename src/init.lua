--[[
TheNexusAvenger

Static instances for region culling.
--]]

local ModelCulling = require(script:WaitForChild("Culling"):WaitForChild("ModelCulling"))
local RegionState = require(script:WaitForChild("State"):WaitForChild("RegionState"))
local BufferedRegionState = require(script:WaitForChild("State"):WaitForChild("BufferedRegionState"))

local RegionCulling = {}
RegionCulling.RegionState = BufferedRegionState.new(RegionState.new())
RegionCulling.ModelCulling = ModelCulling.new(RegionCulling.RegionState)



--[[
Starts all culling loops.
--]]
function RegionCulling:Start(): ()
    self.RegionState:StartUpdating()
    self.ModelCulling:StartProcessingQueue()
    self.ModelCulling:StartModelFlattening()
end



return RegionCulling
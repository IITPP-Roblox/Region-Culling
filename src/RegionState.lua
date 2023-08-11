--[[
TheNexusAvenger

Stores regions and controls which are relevant.
--]]
--!strict

local RegionState = {}
RegionState.__index = RegionState



--[[
Creates a region state.
--]]
function RegionState.new()
    return setmetatable({
        Regions = {},
    }, RegionState)
end

--[[
Returns if a point is in a region.
--]]
function RegionState:InRegion(RegionName: string, Position: Vector3): boolean
    local PositionCFrame = CFrame.new(Position)
    for _, Zone in self.Regions[RegionName].Zones do
        local Size = Zone.Size
        local RelativeCFrame = Zone.Center:Inverse() * PositionCFrame
        if math.abs(RelativeCFrame.X) > Size.X / 2 or math.abs(RelativeCFrame.Y) > Size.Y / 2 or math.abs(RelativeCFrame.Z) > Size.Z / 2 then continue end
        return true
    end
    return false
end

--[[
Returns a dictionary of the visible regions.
--]]
function RegionState:GetVisibleRegions(Position: Vector3): {[string]: boolean}
    local VisibleRegionsMap = {}
    for RegionName, RegionData in self.Regions do
        if not self:InRegion(RegionName, Position) then continue end
        VisibleRegionsMap[RegionName] = true
        for _, VisibleRegionName in RegionData.VisibleRegions do
            VisibleRegionsMap[VisibleRegionName] = true
        end
    end
    return VisibleRegionsMap
end

--[[
Adds a region with a given center and size.
Region names can be non-unique.
--]]
function RegionState:AddRegion(RegionName: string, Center: CFrame, Size: Vector3): ()
    if not self.Regions[RegionName] then
        self.Regions[RegionName] = {
            Zones = {},
            VisibleRegions = {},
        }
    end
    table.insert(self.Regions[RegionName].Zones, {
        Center = Center,
        Size = Size,
    })
end

--[[
Marks a region as visible to another.
--]]
function RegionState:ConnectRegions(RegionName1: string, RegionName2: string): ()
    if not self.Regions[RegionName1] then
        error("Region \""..tostring(RegionName1).."\" does not exist.")
    end
    if not self.Regions[RegionName2] then
        error("Region \""..tostring(RegionName2).."\" does not exist.")
    end
    table.insert(self.Regions[RegionName1].VisibleRegions, RegionName2)
    table.insert(self.Regions[RegionName2].VisibleRegions, RegionName1)
end



return RegionState
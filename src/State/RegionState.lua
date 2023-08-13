--[[
TheNexusAvenger

Stores regions and controls which are relevant.
--]]
--!strict

local Workspace = game:GetService("Workspace")

local Event = require(script.Parent.Parent:WaitForChild("Event"))
local Types = require(script.Parent.Parent:WaitForChild("Types"))

local RegionState = {}
RegionState.__index = RegionState



--[[
Creates a region state.
--]]
function RegionState.new(): Types.RegionState
    return (setmetatable({
        Regions = {},
        VisibleWhenOutsideRegionsMap = {},
        CurrentVisibleRegionsMap = {},
        CurrentVisibleRegions = {},
        RegionVisible = Event.new() :: Event.Event<string>,
        RegionHidden = Event.new() :: Event.Event<string>,
    }, RegionState) :: any) :: Types.RegionState
end

--[[
Returns if a point is in a region.
--]]
function RegionState:IsInRegion(RegionName: string, Position: Vector3): boolean
    local PositionCFrame = CFrame.new(Position)
    if not self.Regions[RegionName] then return false end
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
    local InRegions = false
    for RegionName, RegionData in self.Regions do
        if not self:IsInRegion(RegionName, Position) then continue end
        InRegions = true
        VisibleRegionsMap[RegionName] = true
        for _, VisibleRegionName in RegionData.VisibleRegions do
            VisibleRegionsMap[VisibleRegionName] = true
        end
    end
    if not InRegions then
        return self.VisibleWhenOutsideRegionsMap
    end
    return VisibleRegionsMap
end

--[[
Returns a list of the current visible regions.
--]]
function RegionState:GetCurrentVisibleRegions(): {string}
    return self.CurrentVisibleRegions
end

--[[
Returns if a region is currently visible.
--]]
function RegionState:IsRegionVisible(RegionName: string): boolean
    return self.CurrentVisibleRegionsMap[RegionName] == true
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

--[[
Marks a region as visible when the player is outside all regions.
--]]
function RegionState:SetVisibleWhenOutsideRegions(RegionName: string): ()
    self.VisibleWhenOutsideRegionsMap[RegionName] = true
end

--[[
Updates the visible regions.
--]]
function RegionState:UpdateVisibleRegions(Position: Vector3?): ()
    --Get the visible regions.
    local CurrentVisibleRegionsMap = self.CurrentVisibleRegionsMap
    local NewRegions = self:GetVisibleRegions(Position or Workspace.CurrentCamera:GetRenderCFrame().Position)
    self.CurrentVisibleRegionsMap = NewRegions

    --Store the visible regions as a list.
    local VisibleRegions = {}
    for VisibleRegion, _ in NewRegions do
        table.insert(VisibleRegions, VisibleRegion)
    end
    self.CurrentVisibleRegions = VisibleRegions

    --Fire the events for showing the regions.
    for VisibleRegion, _ in NewRegions do
        if not CurrentVisibleRegionsMap[VisibleRegion] then
            self.RegionVisible:Fire(VisibleRegion)
        end
    end

    --Fire the events for hiding the regions.
    for VisibleRegion, _ in CurrentVisibleRegionsMap do
        if not NewRegions[VisibleRegion] then
            self.RegionHidden:Fire(VisibleRegion)
        end
    end
end

--[[
Starts updating the visible regions.
--]]
function RegionState:StartUpdating(): ()
    self:UpdateVisibleRegions()
    task.spawn(function()
        while true do
            task.wait(0.1)
            self:UpdateVisibleRegions()
        end
    end)
end



return (RegionState :: any) :: Types.RegionState
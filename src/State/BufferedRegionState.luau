--Buffers the regions being hidden from a RegionState to reduce issues
--with players quickly going between 2 regions.
--!strict

local Event = require(script.Parent.Parent:WaitForChild("Event"))
local RegionState = require(script.Parent:WaitForChild("RegionState"))

local BufferedRegionState = {}
BufferedRegionState.__index = BufferedRegionState

export type BufferedRegionState = {
    HiddenRegionTimeout: number,
    WrappedRegionState: RegionState.RegionState,
    CurrentVisibleRegionsMap: {[string]: boolean},
    CurrentVisibleRegions: {string},
    RegionVisible: Event.Event<string>,
    RegionHidden: Event.Event<string>,
} & typeof(setmetatable({}, BufferedRegionState))



--[[
Creates a buffered region state.
--]]
function BufferedRegionState.new(RegionState: RegionState.RegionState): BufferedRegionState
    --Create the object.
    local self = setmetatable({
        HiddenRegionTimeout = 5,
        WrappedRegionState = RegionState,
        CurrentVisibleRegionsMap = {},
        CurrentVisibleRegions = {},
        RegionVisible = Event.new() :: Event.Event<string>,
        RegionHidden = Event.new() :: Event.Event<string>,
    }, BufferedRegionState) :: BufferedRegionState

    --Connect the events.
    local RegionHiddenTimes: {[string]: number} = {}
    RegionState.RegionVisible:Connect(function(RegionName)
        --Reset the time the region was hidden.
        local AlreadyHidden = (RegionHiddenTimes[RegionName] ~= nil)
        RegionHiddenTimes[RegionName] = nil
        if AlreadyHidden then return end

        --Store the region as visible.
        table.insert(self.CurrentVisibleRegions, RegionName)
        self.CurrentVisibleRegionsMap[RegionName] = true
        self.RegionVisible:Fire(RegionName)
    end)
    RegionState.RegionHidden:Connect(function(RegionName)
        --Queue clearing the region.
        local CurrentTime = tick()
        RegionHiddenTimes[RegionName] = CurrentTime
        task.delay(self.HiddenRegionTimeout, function()
            --Clear the region if enough time has passed.
            if RegionHiddenTimes[RegionName] ~= CurrentTime then return end
            RegionHiddenTimes[RegionName] = nil
            for i, OtherRegionName in self.CurrentVisibleRegions do
                if RegionName ~= OtherRegionName then continue end
                table.remove(self.CurrentVisibleRegions, i)
                break
            end
            self.CurrentVisibleRegionsMap[RegionName] = false
            self.RegionHidden:Fire(RegionName)
        end)
    end)

    --Return the object.
    return self
end

--[[
Returns if a point is in a region.
--]]
function BufferedRegionState.IsInRegion(self: BufferedRegionState, RegionName: string, Position: Vector3): boolean
    return self.WrappedRegionState:IsInRegion(RegionName, Position)
end

--[[
Returns a list of the current visible regions.
--]]
function BufferedRegionState.GetCurrentVisibleRegions(self: BufferedRegionState): {string}
    return self.CurrentVisibleRegions
end

--[[
Returns if a region is currently visible.
--]]
function BufferedRegionState.IsRegionVisible(self: BufferedRegionState, RegionName: string): boolean
    return self.CurrentVisibleRegionsMap[RegionName] == true
end

--[[
Adds a region with a function for if the CFrame is in the region.
Region names can be non-unique.
--]]
function BufferedRegionState.AddRegionFunction(self: BufferedRegionState, RegionName: string, InRegionFunction: (Position: CFrame) -> (boolean)): ()
    self.WrappedRegionState:AddRegionFunction(RegionName, InRegionFunction)
end

--[[
Adds a region with a given center and size.
Region names can be non-unique.
--]]
function BufferedRegionState.AddRegion(self: BufferedRegionState, RegionName: string, Center: CFrame, Size: Vector3): ()
    self.WrappedRegionState:AddRegion(RegionName, Center, Size)
end

--[[
Marks a region as visible to another.
--]]
function BufferedRegionState.ConnectRegions(self: BufferedRegionState, RegionName1: string, RegionName2: string): ()
    self.WrappedRegionState:ConnectRegions(RegionName1, RegionName2)
end

--[[
Marks a region as visible when the player is outside all regions.
--]]
function BufferedRegionState.SetVisibleWhenOutsideRegions(self: BufferedRegionState, RegionName: string): ()
    self.WrappedRegionState:SetVisibleWhenOutsideRegions(RegionName)
end

--[[
Starts updating the visible regions.
--]]
function BufferedRegionState.StartUpdating(self: BufferedRegionState): ()
    self.WrappedRegionState:StartUpdating()
end



return BufferedRegionState
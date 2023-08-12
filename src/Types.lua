--[[
TheNexusAvenger

Types of the region culling system.
--]]

local Event = require(script.Parent:WaitForChild("Event"))

export type BaseRegionState = {
    RegionVisible: Event.Event<string>,
    RegionHidden: Event.Event<string>,

    GetCurrentVisibleRegions: (self: BaseRegionState) -> ({string}),
    AddRegion: (self: BaseRegionState, RegionName: string, Center: CFrame, Size: Vector3) -> (),
    ConnectRegions: (self: BaseRegionState, RegionName1: string, RegionName2: string) -> (),
}

export type RegionState = {
    new: () -> (RegionState),
    InRegion: (self: RegionState, RegionName: string, Position: Vector3) -> (boolean),
    GetVisibleRegions: (self: RegionState, Position: Vector3) -> ({[string]: boolean}),
    UpdateVisibleRegions: (self: RegionState, Position: Vector3?) -> (),
    StartUpdating: (self: RegionState) -> (),
} & BaseRegionState

export type BufferedRegionState = {
    HiddenRegionTimeout: number,
    WrappedRegionState: BaseRegionState,
    new: (RegionState: BaseRegionState) -> (BufferedRegionState),
} & BaseRegionState

return true
--[[
TheNexusAvenger

Types of the region culling system.
--]]

local Event = require(script.Parent:WaitForChild("Event"))

--Region state
export type BaseRegionState = {
    RegionVisible: Event.Event<string>,
    RegionHidden: Event.Event<string>,

    GetCurrentVisibleRegions: (self: BaseRegionState) -> ({string}),
    IsRegionVisible: (self: BaseRegionState, RegionName: string) -> (boolean),
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



--Model culling
export type ModelCullingContext = {
    Model: Instance,
    ModelCulling: ModelCulling,
    ModelParent: Instance,
    HiddenParts: {{Part: Instance, Parent: Instance}},
    VisibleWhenOutsideRegions: boolean,
    FlatteningEnabled: boolean,
    ClusteringEnabled: boolean,
    ReparentOperationsPerStep: number?,
    PartClusterSize: number?,
    FlatteningFilters: {(Instance) -> (boolean, string?)},
    UnflattenableModelCache: {[Instance]: boolean},

    new: (Model: Instance, ModelCulling: ModelCulling) -> (ModelCullingContext),
    MakeVisibleWhenOutsideRegions: (self: ModelCullingContext) -> (ModelCullingContext),
    EnableFlattening: (self: ModelCullingContext, OperationsPerStep: number?) -> (ModelCullingContext),
    EnableClustering: (self: ModelCullingContext, PartClusterSize: number?) -> (ModelCullingContext),
    AddFlatteningFilter: (self: ModelCullingContext, Filter: (Instance) -> (boolean, string?)) -> (ModelCullingContext),
    CanFlatten: (self: ModelCullingContext, Child: Instance) -> (boolean),
    FlattenModel: (self: ModelCullingContext) -> (),
    HideModel: (self: ModelCullingContext, RemainingOperations: number) -> (number),
    ShowModel: (self: ModelCullingContext, RemainingOperations: number) -> (number),
}

export type ModelCullingOperation = {
    RegionName: string,
    Operation: string,
    Context: ModelCullingContext,
}

export type ModelCulling = {
    RegionState: BaseRegionState,
    ReparentOperationsPerStep: number,
    PartClusterSize: number,
    ProcessStepDelay: number,
    PassiveModelFlattenDelay: number,
    HiddenGeometry: Folder,
    Contexts: {[string]: {ModelCullingContext}},
    QueuedOperations: {ModelCullingOperation},

    new: (RegionState: BaseRegionState) -> (ModelCulling),
    HandleInitialModel: (self: ModelCulling, RegionName: string, Context: ModelCullingContext) -> (),
    BindModelToRegion: (self: ModelCulling, RegionName: string, Model: Instance) -> (ModelCullingContext),
    RemoveQueuedOperations: (self: ModelCulling, RegionName: string) -> (),
    HideRegion: (self: ModelCulling, RegionName: string) -> (),
    ShowRegion: (self: ModelCulling, RegionName: string) -> (),
    PerformQueueStep: (self: ModelCulling) -> (),
    StartProcessingQueue: (self: ModelCulling) -> (),
    StartModelFlattening: (self: ModelCulling) -> (),
}

return true
--Context for configuring the culling of a model.
--!strict

local GENERIC_CLUSTER_NAME = "Generic"

local ModelCullingContext = {}
ModelCullingContext.__index = ModelCullingContext

export type ClusteringMode = "Instancing" | "MinimumFolders"
export type ModelCullingIssue = {
    Instance: Instance,
    Issues: {string},
}
export type ModelCullingContextSummary = {
    Model: Instance,
    FlattenedParts: number,
    UnflattenedParts: number,
    Issues: {ModelCullingIssue},
}
export type ModelCullingContext = {
    Model: Instance,
    ModelCulling: any,
    ModelParent: Instance,
    HiddenParts: {{Part: Instance, Parent: Instance}},
    ClusterFolders: {[string]: {{Folder: Instance, Total: number}}},
    ClusteringGroupFolders: {Instance},
    OverrideClusterCosts: {[Instance]: number},
    FlatteningEnabled: boolean,
    ClusteringEnabled: boolean,
    ClusteringMode: ClusteringMode,
    ReparentOperationsPerStep: number?,
    PartClusterSize: number?,
    FlatteningFilters: {(Instance) -> (boolean, string?)},
    UnflattenableModelCache: {[Instance]: boolean},
} & typeof(setmetatable({}, ModelCullingContext))



--[[
Creates a model culling context.
--]]
function ModelCullingContext.new(Model: Instance, ModelCulling: any): ModelCullingContext
    return setmetatable({
        Model = Model,
        ModelCulling = ModelCulling,
        ModelParent = Model.Parent,
        HiddenParts = {},
        ClusterFolders = {},
        ClusteringGroupFolders = {},
        OverrideClusterCosts = {},
        FlatteningEnabled = false,
        ClusteringEnabled = false,
        ClusteringMode = "Instancing" :: ClusteringMode,
        FlatteningFilters = {},
        UnflattenableModelCache = {},
    }, ModelCullingContext) :: ModelCullingContext
end

--[[
Enables the model to be flattened. Flattened models move static,
disconnected parts to a separate folder to allow for gradual loading
and unloading. An optional amount of operations per step when showing
the model can be provided, intended for models that need to be shown
faster than others (little time to show or high part count).
--]]
function ModelCullingContext.EnableFlattening(self: ModelCullingContext, OperationsPerStep: number?): ModelCullingContext
    --Enable flattening.
    self.FlatteningEnabled = true
    self.ReparentOperationsPerStep = OperationsPerStep

    --Create the folder.
    if not self.Model:FindFirstChild("StaticParts") then
        local StaticParts = Instance.new("Folder")
        StaticParts.Name = "StaticParts"
        StaticParts.Parent = self.Model
    end

    --Return the context.
    return self
end

--[[
Enables flattened parts of the model to be grouped together into smaller
folders to reduce reparent operations.
--]]
function ModelCullingContext.EnableClustering(self: ModelCullingContext, PartClusterSize: number?, ClusteringMode: ClusteringMode): ModelCullingContext
    --Enable clustering.
    self.ClusteringEnabled = true
    self.PartClusterSize = PartClusterSize
    self.ClusteringMode = ClusteringMode or self.ClusteringMode

    --Return the context.
    return self
end

--[[
Adds a filter used when flattening a model. When true for a given instance,
entire model directly under the model for the context will not be flattened.
The filter function returns a bool for whether the instance can be flattened
and a string value covering why it can't for debugging.
--]]
function ModelCullingContext.AddFlatteningFilter(self: ModelCullingContext, Filter: (Instance) -> (boolean, string?)): ModelCullingContext
    table.insert(self.FlatteningFilters, Filter)
    return self
end

--[[
Returns if an instance can be flattened.
--]]
function ModelCullingContext.CanFlatten(self: ModelCullingContext, Child: Instance): boolean
    --Return false if the child can't be flattened.
    for _, Filter in self.FlatteningFilters do
        local CanFlatten, _ = Filter(Child)
        if CanFlatten then continue end
        return false
    end

    --Return false if a child can't be flattened.
    for _, SubChild in Child:GetChildren() do
        if self:CanFlatten(SubChild) then continue end
        return false
    end

    --Return true (can be flattened).
    return true
end

--[[
Returns if an instance can be flattened.
Caches the results for future runs.
--]]
function ModelCullingContext.CanFlattenCaching(self: ModelCullingContext, Child: Instance): boolean
    local UnflattenableModelCache = self.UnflattenableModelCache
    if not UnflattenableModelCache[Child] and not self:CanFlatten(Child) then
        UnflattenableModelCache[Child] = true
    end
    return UnflattenableModelCache[Child] ~= true
end

--[[
Flattens the current model.
--]]
function ModelCullingContext.FlattenModel(self: ModelCullingContext): ()
    if not self.FlatteningEnabled then return end
    local StaticPartsFolder = self.Model:FindFirstChild("StaticParts") :: Folder
    if not StaticPartsFolder then return end

    --Move parts into the static parts model.
    debug.profilebegin("ModelCullingContext_FlattenModel")
    for _, Child in self.Model:GetChildren() do
        if Child == StaticPartsFolder then continue end
        if not self:CanFlattenCaching(Child) then
            continue
        end
        
        --Move characters out.
        if Child:FindFirstChildOfClass("Humanoid") then
            Child.Parent = StaticPartsFolder
            continue
        end
        for _, Model in Child:GetDescendants() do
            if not Model:FindFirstChildOfClass("Humanoid") then continue end
            Model.Parent = StaticPartsFolder
        end

        --Move the parts.
        if Child:IsA("BasePart") then
            Child.Parent = StaticPartsFolder
        end
        for _, Part in Child:GetDescendants() do
            if not Part:IsA("BasePart") then continue end
            Part.Parent = StaticPartsFolder
        end
    end
    debug.profileend()
    
    --Attempt to cluster parts into models for less Parent changes.
    if not self.ClusteringEnabled then return end
    debug.profilebegin("ModelCullingContext_Clustering")
    local ClusterWithInstance = (self.ClusteringMode == "Instancing")
    local PartClusterSize = self.PartClusterSize or self.ModelCulling.PartClusterSize
    local HiddenGeometry = self.ModelCulling.HiddenGeometry
    for _, Part in StaticPartsFolder:GetChildren() do
        if not Part:IsA("BasePart") then continue end
        
        --Determine the cluster name.
        local ClusterName = GENERIC_CLUSTER_NAME
        if ClusterWithInstance and Part.Transparency == 0 then
            ClusterName = `{Part.BrickColor.Number}_{Part.Material.Value}`
        end

        --Create or get the cluster folder.
        if not self.ClusterFolders[ClusterName] then
            self.ClusterFolders[ClusterName] = {}
        end
        local ExistingClusters = self.ClusterFolders[ClusterName]
        local ExistingCluster = ExistingClusters[#ExistingClusters]
        if not ExistingCluster or ExistingCluster.Total >= PartClusterSize then
            --Create the folder.
            local ClusterFolder = Instance.new("Folder") :: Instance
            ClusterFolder.Name = `PartCluster{ClusterName}`
            if self.Model:IsDescendantOf(HiddenGeometry) then
                table.insert(self.HiddenParts, {Part = ClusterFolder :: Instance, Parent = StaticPartsFolder :: Instance})
                ClusterFolder.Parent = HiddenGeometry
            else
                ClusterFolder.Parent = StaticPartsFolder
            end

            --Store the new folder.
            local NewCluster = {
                Folder = ClusterFolder,
                Total = 0,
            }
            ExistingCluster = NewCluster
            table.insert(ExistingClusters, NewCluster)
        end

        --Add the part to the cluster.
        local ClusterFolder = ExistingCluster.Folder
        Part.Parent = ClusterFolder
        ExistingCluster.Total += 1
        self.OverrideClusterCosts[ClusterFolder] = ExistingCluster.Total

        --Remove the cluster from a group if it is too big.
        if ExistingCluster.Total >= PartClusterSize and ClusterFolder.Parent and ClusterFolder.Parent.Name == "PartClusterGroup" then
            if ClusterFolder:IsDescendantOf(HiddenGeometry) then
                table.insert(self.HiddenParts, {Part = ClusterFolder, Parent = StaticPartsFolder :: Instance})
                ClusterFolder.Parent = HiddenGeometry
            else
                ClusterFolder.Parent = StaticPartsFolder
            end
        end
    end
    debug.profileend()

    --Group the smaller groups of named clusters.
    if not ClusterWithInstance then return end
    debug.profilebegin("ModelCullingContext_ClusterGrouping")
    local ClustersToGroup, ClustersToGroupMap = {}, {}
    for ClusterName, Clusters in self.ClusterFolders do
        if ClusterName == "GENERIC_CLUSTER_NAME" then continue end
        local LastCluster = Clusters[#Clusters]
        if not LastCluster or LastCluster.Total == PartClusterSize then continue end
        table.insert(ClustersToGroup, LastCluster)
        ClustersToGroupMap[LastCluster.Folder] = true
    end
    table.sort(ClustersToGroup, function(a, b) return a.Folder.Name < b.Folder.Name end)

    local ClusteringGroupFolders = self.ClusteringGroupFolders
    local CurrentGroupIndex, CurrentGroupSize = 0, PartClusterSize
    for i, Cluster in ClustersToGroup do
        --Move to the next group if the current group becomes too big.
        if CurrentGroupSize + Cluster.Total > PartClusterSize then
            CurrentGroupIndex += 1
            CurrentGroupSize = 0
        end

        --Create the folder if it doesn't exist.
        if not ClusteringGroupFolders[CurrentGroupIndex] then
            local NewFolder = Instance.new("Folder") :: Instance
            NewFolder.Name = "PartClusterGroup"
            if self.Model:IsDescendantOf(HiddenGeometry) then
                table.insert(self.HiddenParts, {Part = NewFolder, Parent = StaticPartsFolder :: Instance})
                NewFolder.Parent = HiddenGeometry
            else
                NewFolder.Parent = StaticPartsFolder
            end
            ClusteringGroupFolders[CurrentGroupIndex] = NewFolder
        end
        CurrentGroupSize += Cluster.Total

        --Move the cluster to the folder.
        local ClusterFolder = Cluster.Folder
        local NewFolder = ClusteringGroupFolders[CurrentGroupIndex]
        self.OverrideClusterCosts[NewFolder] = CurrentGroupSize
        if ClusterFolder.Parent == NewFolder then continue end
        ClusterFolder.Parent = NewFolder
    end

    local HiddenParts = self.HiddenParts
    for i = #HiddenParts, 1, -1 do
        local HiddenPart = HiddenParts[i]
        if not ClustersToGroupMap[HiddenPart.Part] then continue end
        table.remove(HiddenParts, i)
    end
    debug.profileend()
end

--[[
Returns a summary for the model culling context.
--]]
function ModelCullingContext.GetSummary(self: ModelCullingContext): ModelCullingContextSummary
    --Create the initial summary.
    local Summary = {
        Model = self.Model,
        FlattenedParts = 0,
        UnflattenedParts = 0,
        Issues = {},
    }

    --Get the lists of instances to iterate over.
    local ModelDescendants = self.Model:GetDescendants()
    local HiddenParts = {}
    local HiddenDescendants = {}
    for _, PartData in self.HiddenParts do
        table.insert(HiddenParts, PartData.Part)
        for _, Child in PartData.Part:GetDescendants() do
            table.insert(HiddenDescendants, Child)
        end
    end

    --Iterate over the instances.
    local StaticAnchoredParts = self.Model:FindFirstChild("StaticParts") :: Folder
    for _, ChildGroup in {ModelDescendants, HiddenParts, HiddenDescendants} do
        for _, Child in ChildGroup do
            --Add the part.
            if Child:IsA("BasePart") then
                if StaticAnchoredParts and (Child:IsDescendantOf(StaticAnchoredParts) or not Child:IsDescendantOf(self.Model)) then
                    Summary.FlattenedParts += 1
                else
                    Summary.UnflattenedParts += 1
                end
            end

            --Add the problems.
            local Issues = {}
            for _, Filter in self.FlatteningFilters do
                local CanFlatten, Issue = Filter(Child)
                if CanFlatten then continue end
                table.insert(Issues, Issue :: string)
            end
            if #Issues > 0 then
                table.insert(Summary.Issues, {
                    Instance = Child,
                    Issues = Issues,
                })
            end
        end
    end

    --Return the summary.
    return Summary
end

--[[
Hides the current model using the given amoung of operations. Returns the
remaining operations.
--]]
function ModelCullingContext.HideModel(self: ModelCullingContext, RemainingOperations: number): number
    --Move static parts.
    debug.profilebegin("ModelCullingContext_HideModel")
    local StaticAnchoredParts = self.Model:FindFirstChild("StaticParts") :: Folder
    local HiddenGeometry = self.ModelCulling.HiddenGeometry
    if StaticAnchoredParts then
        local StaticAnchoredPartsToMove = StaticAnchoredParts:GetChildren()
        table.sort(StaticAnchoredPartsToMove, function(a, b) return a.Name < b.Name end)
        for i = #StaticAnchoredPartsToMove, 1, -1 do
            if RemainingOperations <= 0 then break end
            local Part = StaticAnchoredPartsToMove[i]
            Part.Parent = HiddenGeometry
            table.insert(self.HiddenParts, {Part = Part, Parent = StaticAnchoredParts :: Instance})
            RemainingOperations += -(self.OverrideClusterCosts[Part] or (Part:IsA("Model") or Part:IsA("Folder")) and #Part:GetChildren() or 1)
        end
    end

    --Move the model and remove the queued action
    if RemainingOperations > 0 and self.Model.Parent ~= HiddenGeometry and (not StaticAnchoredParts or #StaticAnchoredParts:GetChildren() == 0) then
        local MovedParts = 0
        for _, Part in self.Model:GetDescendants() do
            if not Part:IsA("BasePart") then continue end
            MovedParts += 1
        end
        self.Model.Parent = HiddenGeometry
        RemainingOperations += -MovedParts
    end
    debug.profileend()

    --Return thee remaining operations.
    return math.max(0, RemainingOperations)
end

--[[
Shows the current model using the given amoung of operations. Returns the
remaining operations.
--]]
function ModelCullingContext.ShowModel(self: ModelCullingContext, RemainingOperations: number): number
    --Move the model.
    debug.profilebegin("ModelCullingContext_ShowModel")
    if self.Model.Parent ~= self.ModelParent then
        local MovedParts = 0
        for _, Part in self.Model:GetDescendants() do
            if not Part:IsA("BasePart") then continue end
            MovedParts += 1
        end
        self.Model.Parent = self.ModelParent
        RemainingOperations += -MovedParts
    end

    --Move static parts.
    for i = #self.HiddenParts, 1, -1 do
        if RemainingOperations <= 0 then break end
        local Entry = table.remove(self.HiddenParts, i) :: {Part: Instance, Parent: Instance}
        local Part, Parent = Entry.Part, Entry.Parent
        Part.Parent = Parent
        RemainingOperations += -(self.OverrideClusterCosts[Part] or Part:IsA("BasePart") and 1 or #Part:GetChildren())
    end
    debug.profileend()

    --Return the remaining operations.
    return math.max(0, RemainingOperations)
end



return ModelCullingContext
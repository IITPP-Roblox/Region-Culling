--[[
TheNexusAvenger

Controls showing and hiding of models.
--]]
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModelCullingContext = require(script.Parent:WaitForChild("ModelCullingContext"))
local Types = require(script.Parent.Parent:WaitForChild("Types"))

local ModelCulling = {}
ModelCulling.__index = ModelCulling



--[[
Creates a model culling controller.
--]]
function ModelCulling.new(RegionState: Types.BaseRegionState): Types.ModelCulling
    --Create the object.
    local self = (setmetatable({
        RegionState = RegionState,
        ReparentOperationsPerStep = 250,
        PartClusterSize = 50,
        ProcessStepDelay = 1 / 30,
        PassiveModelFlattenDelay = 5,
        Contexts = {},
        QueuedOperations = {},
        WasInNoRegions = false,
    }, ModelCulling) :: any) :: Types.ModelCulling

    --Create the hidden geometry folder.
    --ReplicatedStorage is used to ensure replication still happens.
    if not ReplicatedStorage:FindFirstChild("ModelCullingHiddenGeometry") then
        local HiddenGeometry = Instance.new("Folder")
        HiddenGeometry.Name = "ModelCullingHiddenGeometry"
        HiddenGeometry.Parent = ReplicatedStorage
    end
    self.HiddenGeometry = ReplicatedStorage:FindFirstChild("ModelCullingHiddenGeometry")

    --Connect the region state events.
    RegionState.RegionVisible:Connect(function(RegionName)
        self:ShowRegion(RegionName)
    end)
    RegionState.RegionHidden:Connect(function(RegionName)
        self:HideRegion(RegionName)
    end)

    --Return the object.
    return self
end

--[[
Handles a model being added.
--]]
function ModelCulling:HandleInitialModel(RegionName: string, Context: Types.ModelCullingContext): ()
    local VisibleRegions = self.RegionState:GetCurrentVisibleRegions()
    if not self.RegionState:IsRegionVisible(RegionName) and not (#VisibleRegions == 0 and Context.VisibleWhenOutsideRegions) then
        table.insert(self.QueuedOperations, {
            RegionName = RegionName,
            Operation = "Hide",
            Context = Context,
        })
    end
end

--[[
Binds a model to a region. Returns a context for further configuring.
--]]
function ModelCulling:BindModelToRegion(RegionName: string, Model: Instance): Types.ModelCullingContext
    --Create the context.
    local Context = ModelCullingContext.new(Model, self)
    if not self.Contexts[RegionName] then
        self.Contexts[RegionName] = {}
    end
    table.insert(self.Contexts[RegionName], Context)

    --Hide the model if it isn't meant to be visible.
    --Done after 1 second to allow for configuration and prevent Roblox locking the parent of new models.
    task.delay(1, function()
        Context:FlattenModel()
        self:HandleInitialModel(RegionName, Context)
    end)

    --Return the context.
    return Context
end

--[[
Removes queued operations for a region.
--]]
function ModelCulling:RemoveQueuedOperations(RegionName: string): ()
    for i = #self.QueuedOperations, 1, -1 do
        if self.QueuedOperations[i].RegionName ~= RegionName then continue end
        table.remove(self.QueuedOperations, i)
    end
end

--[[
Queues a region to be hidden.
--]]
function ModelCulling:HideRegion(RegionName: string): ()
    self:RemoveQueuedOperations(RegionName)

    --Hide models for the region.
    if self.Contexts[RegionName] then
        for _, Context in self.Contexts[RegionName] do
            table.insert(self.QueuedOperations, {
                RegionName = RegionName,
                Operation = "Hide",
                Context = Context,
            })
        end
    end

    --Show models that are visible when the player is in no region.
    if #self.RegionState:GetCurrentVisibleRegions() == 0 then
        self.WasInNoRegions = true
        for _, Contexts in self.Contexts do
            for _, Context in Contexts do
                if not Context.VisibleWhenOutsideRegions then continue end
                for i = #self.QueuedOperations, 1, -1 do
                    if self.QueuedOperations[i].Context ~= Context then continue end
                    table.remove(self.QueuedOperations, i)
                end
                table.insert(self.QueuedOperations, 1, {
                    RegionName = RegionName,
                    Operation = "Show",
                    Context = Context,
                })
            end
        end
    end
end

--[[
Queues a region to be shown.
--]]
function ModelCulling:ShowRegion(RegionName: string): ()
    self:RemoveQueuedOperations(RegionName)

    --Show models for the region.
    if self.Contexts[RegionName] then
        for _, Context in self.Contexts[RegionName] do
            table.insert(self.QueuedOperations, 1, {
                RegionName = RegionName,
                Operation = "Show",
                Context = Context,
            })
        end
    end

    --Hide the models that are visible when in no regions.
    if self.WasInNoRegions then
        for RegionName, Contexts in self.Contexts do
            if self.RegionState:IsRegionVisible(RegionName) then continue end
            for _, Context in Contexts do
                if not Context.VisibleWhenOutsideRegions then continue end
                table.insert(self.QueuedOperations, {
                    RegionName = RegionName,
                    Operation = "Hide",
                    Context = Context,
                })
            end
        end
    end
end

--[[
Processes a single step of operations of the queue.
--]]
function ModelCulling:PerformQueueStep(): ()
    --Get the initial operations to perform.
    local RemainingOperations = self.ReparentOperationsPerStep
    for _, PendingOperation in self.QueuedOperations do
        if PendingOperation.Operation ~= "Show" then continue end
        if not PendingOperation.Context.ReparentOperationsPerStep then continue end
        RemainingOperations = math.max(RemainingOperations, PendingOperation.Context.ReparentOperationsPerStep)
    end

    --Perform queue actions.
    while RemainingOperations > 0 and #self.QueuedOperations > 0 do
        --Perform the operation.
        local NewRemainingOperations = RemainingOperations
        local NextOperation = self.QueuedOperations[1]
        if NextOperation.Operation == "Show" then
            NewRemainingOperations = NextOperation.Context:ShowModel(RemainingOperations)
        elseif NextOperation.Operation == "Hide" then
            NewRemainingOperations = NextOperation.Context:HideModel(RemainingOperations)
        end

        --Remove the queued operation if there are excess remaining operations.
        --Incomplete operations should always have NewRemainingOperations as 0.
        if NewRemainingOperations ~= 0 then
            table.remove(self.QueuedOperations, 1)
        end
        RemainingOperations = NewRemainingOperations
    end
end

--[[
Starts processing the queue.
--]]
function ModelCulling:StartProcessingQueue(): ()
    --Start the loop.
    task.spawn(function()
        while true do
            self:PerformQueueStep()
            task.wait(self.ProcessStepDelay)
        end
    end)

    --Handle existing models.
    for RegionName, Contexts in self.Contexts do
        for _, Context in Contexts do
            self:HandleInitialModel(RegionName, Context)
        end
    end
end

--[[
Starts passively flattening models in the background.
Only intended for models that change (such as StreamingEnabled).
--]]
function ModelCulling:StartModelFlattening(): ()
    while true do
		for RegionName, Contexts in self.Contexts do
			for _, Context in Contexts do
                Context:FlattenModel()
                task.wait()
            end
		end
		task.wait(self.PassiveModelFlattenDelay)
	end
end



return (ModelCulling :: any) :: Types.ModelCulling
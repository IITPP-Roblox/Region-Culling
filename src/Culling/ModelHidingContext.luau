--Context for configuring the hiding (not reparenting) of a model.
--This was added after ModelCullingContext and after LocalTransparencyModified was added to more instances.
--It is meant to be API-compatible with ModelCullingContext.
--!strict

local SET_HIDDEN_METHODS = {
    {
        Classes = {
            "BasePart",
            "Beam",
            "Decal",
            --"Explosion", --Explosions do not last long.
            "Fire",
            "ParticleEmitter",
            "Smoke",
            "Sparkles",
            "Trail",
        },
        SetHidden = function(Ins: Instance, Hidden: boolean): ()
            (Ins :: BasePart).LocalTransparencyModifier = (Hidden and 1 or 0)
        end,
    },
    {
        Classes = {
            "SurfaceGui",
            "BillboardGui",
        },
        SetHidden = function(Ins: Instance, Hidden: boolean): ()
            local OriginalMaxDistance = Ins:GetAttribute("OriginalMaxDistance") :: number
            if Hidden then
                if OriginalMaxDistance then return end
                Ins:SetAttribute("OriginalMaxDistance", (Ins :: SurfaceGui).MaxDistance);
                (Ins :: SurfaceGui).MaxDistance = 0.0001
            else
                if not OriginalMaxDistance then return end
                Ins:SetAttribute("OriginalMaxDistance", nil);
                (Ins :: SurfaceGui).MaxDistance = OriginalMaxDistance
            end
        end,
    },
    {
        Classes = {
            "Constraint",
            "GuiBase3d",
        },
        SetHidden = function(Ins: Instance, Hidden: boolean): ()
            if Hidden then
                if not (Ins :: Constraint).Visible then return end
                Ins:SetAttribute("WasHidden", true);
                (Ins :: Constraint).Visible = false
            else
                if not Ins:GetAttribute("WasHidden") then return end
                Ins:SetAttribute("WasHidden", nil);
                (Ins :: Constraint).Visible = true
            end
        end,
    },
    {
        Classes = {
            "Dialog",
        },
        SetHidden = function(Ins: Instance, Hidden: boolean): ()
            if Hidden then
                if (Ins :: Dialog).InUse then return end
                Ins:SetAttribute("WasHidden", true);
                (Ins :: Dialog).InUse = true
            else
                if not Ins:GetAttribute("WasHidden") then return end
                Ins:SetAttribute("WasHidden", nil);
                (Ins :: Dialog).InUse = false
            end
        end,
    },
} :: {
    {
        Classes: {string},
        SetHidden: SetHiddenMethod,
    }
}

local ModelCullingContext = require(script.Parent:WaitForChild("ModelCullingContext"))

local ModelHidingContext = {}
ModelHidingContext.SetHiddenMethodsByClass = {} :: {[string]: SetHiddenMethod | false}
ModelHidingContext.__index = ModelHidingContext

export type SetHiddenMethod = (Ins: Instance, Hidden: boolean) -> ()
export type ModelHidingContext = {
    Model: Instance,
    ModelHidden: boolean,
    HidableInstances: {Instance},
    HideInstanceMethods: {[Instance]: SetHiddenMethod},
    EventConnections: {RBXScriptConnection},
    LastUpdateIndex: number?,
} & typeof(setmetatable({}, ModelHidingContext))



--[[
Creates a model hiding context.
--]]
function ModelHidingContext.new(Model: Instance): ModelHidingContext
    --Create the object.
    local self = setmetatable({
        Model = Model,
        ModelHidden = false,
        HidableInstances = {},
        HideInstanceMethods = {},
        EventConnections = {},
    }, ModelHidingContext) :: ModelHidingContext

    --Connect parts being added or removed from the model.
    table.insert(self.EventConnections, Model.DescendantAdded:Connect(function(Child)
        self:AddInstances(Child)
    end))
    table.insert(self.EventConnections, Model.DescendantRemoving:Connect(function(Child)
        --Return if the child doesn't exist.
        local ChildIndex = table.find(self.HidableInstances, Child)
        if not ChildIndex then return end

        --Remove the instance.
        table.remove(self.HidableInstances, ChildIndex)
        self.HideInstanceMethods[Child] = nil
        if not self.ModelHidden then return end
        (Child :: BasePart).LocalTransparencyModifier = 0
    end))
    for _, Child in Model:GetDescendants() do
        self:AddInstances(Child)
    end

    --Return the object.
    return self
end

--[[
Adds an instance to the model hiding context.
--]]
function ModelHidingContext.AddInstances(self: ModelHidingContext, Child: Instance): ()
    --Determine the method to hide the instance, and return if there is none.
    --The results are cached by ClassName for faster referneces.
    if self.SetHiddenMethodsByClass[Child.ClassName] == nil then
        local HasSetHiddenMethod = false
        for _, SetHiddenMethodsGroup in SET_HIDDEN_METHODS do
            local InGroup = false
            for _, ClassName in SetHiddenMethodsGroup.Classes do
                if not Child:IsA(ClassName) then continue end
                InGroup = true
                break
            end

            if not InGroup then continue end
            HasSetHiddenMethod = true
            self.SetHiddenMethodsByClass[Child.ClassName] = SetHiddenMethodsGroup.SetHidden
            break
        end

        if not HasSetHiddenMethod then
            self.SetHiddenMethodsByClass[Child.ClassName] = false
        end
    end
    local SetHiddenMethod = self.SetHiddenMethodsByClass[Child.ClassName]
    if not SetHiddenMethod then return end

    --Add the child. Hide the child if the model is hidden.
    table.insert(self.HidableInstances, Child)
    self.HideInstanceMethods[Child] = (SetHiddenMethod :: SetHiddenMethod)
    if not self.ModelHidden then return end
    (SetHiddenMethod :: SetHiddenMethod)(Child, true)
end

--[[
Enables flattening.
Does nothing for model hiding since no reparents are done.
--]]
function ModelHidingContext.EnableFlattening(self: ModelHidingContext, OperationsPerStep: number?): ModelHidingContext
    return self
end

--[[
Enables clustering.
Does nothing for model hiding since flattening is not supported.
--]]
function ModelHidingContext.EnableClustering(self: ModelHidingContext, PartClusterSize: number?): ModelHidingContext
    return self
end

--[[
Adds a flattening filter.
Does nothing for model hiding since flattening is not supported.
--]]
function ModelHidingContext.AddFlatteningFilter(self: ModelHidingContext, Filter: (Instance) -> (boolean, string?)): ModelHidingContext
    return self
end

--[[
Flattens the current model.
Does nothing for model hiding since flattening is not supported.
--]]
function ModelHidingContext.FlattenModel(self: ModelHidingContext): ()
    --No implementation.
end

--[[
Returns a summary for the model culling context.
The summary has no useful data since flattening is not supported.
--]]
function ModelHidingContext.GetSummary(self: ModelHidingContext): ModelCullingContext.ModelCullingContextSummary
    return {
        Model = self.Model,
        FlattenedParts = 0,
        UnflattenedParts = 0,
        Issues = {},
    }
end

--[[
Updates the visibility of the model. Returns the remaining operations.
--]]
function ModelHidingContext.SetVisibility(self: ModelHidingContext, Hidden: boolean, RemainingOperations: number): number
    --Determine the index.
    if self.ModelHidden ~= Hidden or not self.LastUpdateIndex then
        self.ModelHidden = Hidden
        self.LastUpdateIndex = 1
    end
    local LastUpdateIndex = self.LastUpdateIndex :: number

    --Hide the parts.
    local HidableInstances = self.HidableInstances
    local HideInstanceMethods = self.HideInstanceMethods
    local MaxIndex = math.min(LastUpdateIndex + RemainingOperations - 1, #HidableInstances)
    for i = LastUpdateIndex, MaxIndex do
        local HidableInstance = HidableInstances[i];
        HideInstanceMethods[HidableInstance](HidableInstance, Hidden)
    end
    self.LastUpdateIndex = MaxIndex + 1
    return RemainingOperations - math.max(0, MaxIndex - LastUpdateIndex + 1)
end

--[[
Hides the current model using the given amoung of operations. Returns the
remaining operations.
--]]
function ModelHidingContext.HideModel(self: ModelHidingContext, RemainingOperations: number): number
    return self:SetVisibility(true, RemainingOperations)
end

--[[
Shows the current model using the given amoung of operations. Returns the
remaining operations.
--]]
function ModelHidingContext.ShowModel(self: ModelHidingContext, RemainingOperations: number): number
    return self:SetVisibility(false, RemainingOperations)
end



return ModelHidingContext
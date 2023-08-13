--[[
TheNexusAvenger

Demo for the object culling.
--]]
--!strict

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RegionCulling = require(ReplicatedStorage:WaitForChild("RegionCulling"))
local RegionState = RegionCulling.RegionState
local ModelCulling = RegionCulling.ModelCulling



--Set the test values that apply to all models.
RegionState.HiddenRegionTimeout = 2
ModelCulling.ReparentOperationsPerStep = 20

--Create the regions.
for X = -2, 2 do
    for Y = -2, 2 do
        local Name = tostring(X).."_"..tostring(Y)
        local Model = Instance.new("Model")
        Model.Name = Name
        Model.Parent = Workspace

        local CenterCFrame = CFrame.new(20 * X, 10, 20 * Y)
        local BoundsPart = Instance.new("Part")
        BoundsPart.BrickColor = BrickColor.new("Really red")
        BoundsPart.Transparency = 0.8
        BoundsPart.Anchored = true
        BoundsPart.CanCollide = false
        BoundsPart.Size = Vector3.new(20, 20, 20)
        BoundsPart.CFrame = CenterCFrame
        BoundsPart.Parent = Model

        for i = 1, 50 do
            local Part = Instance.new("Part")
            Part.Transparency = 0
            Part.Anchored = true
            Part.CanCollide = false
            Part.Size = Vector3.new(1, 1, 1)
            Part.CFrame = CenterCFrame * CFrame.new(math.random(-10, 10), math.random(-10, 10), math.random(-10, 10))
            Part.Parent = Model 
        end

        RegionState:AddRegion(Name, CenterCFrame, Vector3.new(20, 20, 20))
        local Context = ModelCulling:BindModelToRegion(Name, Model):EnableFlattening():EnableClustering(5)
        if X == -2 or X == 2 or Y == -2 or Y == 2 then
            Context:MakeVisibleWhenOutsideRegions()
        end
    end
end

--Connect the regions.
for X = -2, 2 do
    for Y = -2, 2 do
        local Name = tostring(X).."_"..tostring(Y)
        for _, Offset in {Vector2.new(0, -1), Vector2.new(0, 1), Vector2.new(-1, 0), Vector2.new(1, 0)} do
            local ConnectedName = tostring(X + Offset.X).."_"..tostring(Y + Offset.Y)
            if not Workspace:FindFirstChild(ConnectedName) then continue end
            RegionState:ConnectRegions(Name, ConnectedName)
        end
    end
end

--Start the loops.
--Can be done before or after adding models, but must be after creating regions.
RegionCulling:Start()
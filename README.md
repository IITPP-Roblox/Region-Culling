# Region-Culling
Region culling is a system to gradually load and unload large
sections of maps. Unloading parts of the map can lead to
very high performance improvements since Roblox does not handle
this automatically.

# Setup
## RegionState
`RegionState` controls what regions are visible. Regions are
made of 1 or multiple bounding boxes (CFrame and size) with
connections to other regions for visibility. Optionally, they
can also be made visible when no regions are visible.

`BufferedRegionState` is included and used by default. When
`RegionState` makes a region no longer visible, `BufferedRegionState`
will wait a couple of seconds (default is 5 seconds) to reduce
regions being unloaded and quickly reloaded. 0 disables buffering
entirely, which is useful for testing to ensure region connections
aren't missing.

```luau
--Location of RegionCulling can be anywhere the client can see.
--Using the main module is not required, but it does reduce setup a bit for most cases.
local RegionCulling = require(game:GetService("ReplicatedStorage"):WaitForChild("RegionCulling"))
local RegionState = RegionCulling.RegionState
local ModelCulling = RegionCulling.ModelCulling

--Optional - Change the time hidden region events are delayed.
RegionState.HiddenRegionTimeout = 2

--Add 3 regions.
--Region 1 is made of 2 zones.
--Region 3 can be seen when the camera is outside the regions.
RegionState:AddRegion("Region1", CFrame.new(0, 0, 0), Vector3.new(2, 2, 2))
RegionState:AddRegion("Region1", CFrame.new(0, 4, 0), Vector3.new(2, 2, 2))
RegionState:AddRegion("Region2", CFrame.new(0, 0, 4), Vector3.new(2, 2, 2))
RegionState:AddRegionFunction("Region3", function(Position: CFrame): boolean --Function-based regions can be used for custom cases.
    return Position.Position.Magnitude < 10
end)
RegionState:SetVisibleWhenOutsideRegions("Region3")

--Make it so region 1 can see 2 and 3.
--ConnectRegions makes it so both regions can see each other.
RegionStateObject:ConnectRegions("Region1", "Region2")
RegionStateObject:ConnectRegions("Region1", "Region3")

--Set up the models (next section)

--Start the update loops.
--Camera:GetRenderCFrame() is used for checking where the player is.
RegionCulling:Start()
```

`RegionState` can also be read by other scripts.

```luau
--Location of RegionCulling can be anywhere the client can see.
--Using the main module is not required, but it does reduce setup a bit for most cases.
local RegionCulling = require(game:GetService("ReplicatedStorage"):WaitForChild("RegionCulling"))
local RegionState = RegionCulling.RegionState

--Listen to events being shown or hidden.
RegionState.RegionVisible:Connect(function(RegionName: string) ... end)
RegionState.RegionHidden:Connect(function(RegionName: string) ... end)

--Check if a region is visible.
local VisibleRegions = RegionState:GetCurrentVisibleRegions() --List of the region names that are visible
local IsVisible = RegionState:IsRegionVisible("Region1") --Bool for if a region is visible
local InRegion = RegionState:IsInRegion("Region1", Vector3.new()) --Bool for if a point is in a region
```

## ModelCulling
`ModelCulling` controls the hiding of models based on `RegionState`.
Almost all API calls will be to `BindModelToRegion`, which returns
a context for managing additional configuration.

To enable gradual loading/unloading for a model, `EnableFlattening`
in the context must be called. `ModelCulling` has the number value
`ReparentOperationsPerStep` for how many reparent operations are 
attempted per update step. A number too high will harm performance
when loading/unloading, while a number too low will have visible
loading to players. 250 is default, but it may need to be tuned
for the specific game. Numbers specific to models can be configured
in `EnableFlattening`.

With model flattening, reparenting operations can be done by calling
`EnableClustering`. It will group parts together into folders of
the given size or `PartClusterSize` in `ModelCulling`, with 50 as
default.

```luau
--Location of RegionCulling can be anywhere the client can see.
--Using the main module is not required, but it does reduce setup a bit for most cases.
local RegionCulling = require(game:GetService("ReplicatedStorage"):WaitForChild("RegionCulling"))
local RegionState = RegionCulling.RegionState
local ModelCulling = RegionCulling.ModelCulling

--Optional - change the reparent operations per step and cluster size.
ModelCulling.ReparentOperationsPerStep = 300
ModelCulling.PartClusterSize = 75

--Set up the regions (previous section)

--Bind models.
--Multiple models can be found to a region.
--Can be safely done before and after starting the update loops.
local Context1 = ModelCulling:BindModelToRegion("Region1", game:GetService("Workspace"):WaitForChild("Model1"))
Context1:EnableFlattening() --Enables model flattening with the default reparent operations per step.
Context1:EnableClustering() --Enables clustering while flattening with the default cluster size.

local Context2 = ModelCulling:BindModelToRegion("Region2", game:GetService("Workspace"):WaitForChild("Model2"))
Context2:EnableFlattening(500) --Enables model flattening with a custom reparent operations per step.
Context2:EnableClustering(100) --Enables clustering while flattening a custom default cluster size.

local Context3 = ModelCulling:BindModelToRegion("Region2", game:GetService("Workspace"):WaitForChild("Model2A"))
--Context2:EnableFlattening() --Flattening is NOT enabled. EnableClustering() has no effect without EnableFlattening().

--Add filters for what parts to flatten.
--Filters return true if an instance can be flattened, with an optioanl string saying why they can't.
--Be aware a single instance not being flattened will result in the entire instance tree under the model being unflattened (see next section).
--Context3 is not passed in because EnableFlattening() was not called.
for _, Context in {Context1, Context2} do
    --A filter for Humanoids is not added because Humanoids are special-cased to move together.
    Context:AddFlatteningFilter(function(Child: Instance): (boolean, string?)
        return not Child:IsA("BasePart") or Child.Anchored, "Part is not anchored."
    end)
    Context:AddFlatteningFilter(function(Child: Instance): (boolean, string?)
        return not Child:IsA("BaseScript"), "Scripted instances are not safe to be flattened."
    end)
end

--Start the update loops.
--Camera:GetRenderCFrame() is used for checking where the player is.
RegionCulling:Start()
```

### Using `LocalTransparencyModifier`
`ModelCulling` can be configured to use `LocalTransparencyModifier`.
It will retain collisions and will have less lag when loading/unloading,
but CPU frame times will still be worse compared to not having the
instances in `Workspace`.

```luau
--Location of RegionCulling can be anywhere the client can see.
--Using the main module is not required, but it does reduce setup a bit for most cases.
local RegionCulling = require(game:GetService("ReplicatedStorage"):WaitForChild("RegionCulling"))
local ModelCulling = RegionCulling.ModelCulling

--Change the model culling strategy.
ModelCulling.ModelCullingStrategy = "Transparency"

--Optional - change the transparency operations per step. Clustering is not supported.
--In general, TransparencyOperationsPerStep can be many times ReparentOperationsPerStep.
ModelCulling.TransparencyOperationsPerStep = 800
```

# Diagnosing Performance With `AddFlatteningFilter`
When `AddFlatteningFilter` is used, it can cause large amounts of
instances to not be gradually loaded and unloaded. As an example,
if `Workspace.Model` is bound to a region and `Workspace.Model.SubModel1.SubModel2.SubModel3.Part`
fails the filter, the entire model under `Workspace.Model.SubModel1`
will be stuck loading and unloading together, even if only a
single instance is a problem.

To diagnose problems, use `ModelCulling:GetSummary()`. It returns
a dictionary of region names to a list of `ModelCullingContextSummary`.
`ModelCullingContextSummary` contains the instance (`Model`), number
of flattened parts (`FlattenedParts`), number of unflattened parts
(`UnflattenedParts`), and a list of `ModelCullingIssue` (`Issues`).
Each `ModelCullingIssue` will include the problematic instance (`Instance`)
and a list of all the filter reasons (`Issues`). Sorting by the
most `UnflattenedParts` by model (NOT by region) will show the most
problems. With the issues, either move the problematic models to separate
models or change the filter to allow them through.

**The results of `ModelCulling:GetSummary()` may change over time**,
either because of scripts, unanchored parts being removed, or instance
streaming. Clustering is done 1 model every 1/30th of a second by default
with a delay of 5 seconds (can be changed with `ModelCulling.PassiveModelFlattenDelay`)
before retrying. Waiting may be required before getting a proper reading.

# License
This project is available under the terms of the MIT License.
See [LICENSE](LICENSE) for details.

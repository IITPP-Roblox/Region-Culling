--[[
TheNexusAvenger

Tests the RegionState class.
--]]
--!strict

local RegionState = require(game:GetService("ReplicatedStorage"):WaitForChild("RegionCulling"):WaitForChild("State"):WaitForChild("RegionState"))

return function()
    describe("A region state", function()
        local RegionStateObject = nil
        beforeEach(function()
            RegionStateObject = RegionState.new()
            RegionStateObject:AddRegion("Region1", CFrame.new(0, 0, 0), Vector3.new(2, 2, 2))
            RegionStateObject:AddRegion("Region1", CFrame.new(0, 4, 0), Vector3.new(2, 2, 2))
            RegionStateObject:AddRegion("Region2", CFrame.new(0, 0, 4), Vector3.new(2, 2, 2))
            RegionStateObject:AddRegion("Region3", CFrame.new(0, 0, 6), Vector3.new(2, 2, 2))
            RegionStateObject:ConnectRegions("Region1", "Region2")
            RegionStateObject:ConnectRegions("Region1", "Region3")
        end)

        it("should return if a point is in a region.", function()
            expect(RegionStateObject:IsInRegion("Region1", Vector3.new(0, 0, 0))).to.equal(true)
            expect(RegionStateObject:IsInRegion("Region1", Vector3.new(0, -1, 0))).to.equal(true)
            expect(RegionStateObject:IsInRegion("Region1", Vector3.new(0, 1, 0))).to.equal(true)
            expect(RegionStateObject:IsInRegion("Region1", Vector3.new(0, 4, 0))).to.equal(true)

            expect(RegionStateObject:IsInRegion("Region1", Vector3.new(2, 0, 0))).to.equal(false)
            expect(RegionStateObject:IsInRegion("Region1", Vector3.new(0, 2, 0))).to.equal(false)
            expect(RegionStateObject:IsInRegion("Region1", Vector3.new(0, 0, 2))).to.equal(false)
        end)

        it("should return the visible regions.", function()
            local VisibleRegions = RegionStateObject:GetVisibleRegions(Vector3.new(0, 0, 0))
            expect(VisibleRegions["Region1"]).to.equal(true)
            expect(VisibleRegions["Region2"]).to.equal(true)
            expect(VisibleRegions["Region3"]).to.equal(true)

            VisibleRegions = RegionStateObject:GetVisibleRegions(Vector3.new(0, 0, 4))
            expect(VisibleRegions["Region1"]).to.equal(true)
            expect(VisibleRegions["Region2"]).to.equal(true)
            expect(VisibleRegions["Region3"]).to.equal(nil)

            VisibleRegions = RegionStateObject:GetVisibleRegions(Vector3.new(0, 0, 6))
            expect(VisibleRegions["Region1"]).to.equal(true)
            expect(VisibleRegions["Region2"]).to.equal(nil)
            expect(VisibleRegions["Region3"]).to.equal(true)

            VisibleRegions = RegionStateObject:GetVisibleRegions(Vector3.new(0, 0, 5))
            expect(VisibleRegions["Region1"]).to.equal(true)
            expect(VisibleRegions["Region2"]).to.equal(true)
            expect(VisibleRegions["Region3"]).to.equal(true)

            VisibleRegions = RegionStateObject:GetVisibleRegions(Vector3.new(0, 0, 10))
            expect(VisibleRegions["Region1"]).to.equal(nil)
            expect(VisibleRegions["Region2"]).to.equal(nil)
            expect(VisibleRegions["Region3"]).to.equal(nil)

            RegionStateObject:SetVisibleWhenOutsideRegions("Region1")
            RegionStateObject:SetVisibleWhenOutsideRegions("Region3")
            expect(VisibleRegions["Region1"]).to.equal(true)
            expect(VisibleRegions["Region2"]).to.equal(nil)
            expect(VisibleRegions["Region3"]).to.equal(true)
        end)

        it("should error when connecting unknown regions.", function()
            expect(function() RegionStateObject:ConnectRegions("Region4", "Region3") end).to.throw("Region \"Region4\" does not exist.")
            expect(function() RegionStateObject:ConnectRegions("Region1", "Region4") end).to.throw("Region \"Region4\" does not exist.")
        end)

        it("should fire events.", function()
            local VisibleEvents, HiddenEvents = {} :: {[string]: boolean}, {} :: {[string]: boolean}
            RegionStateObject.RegionVisible:Connect(function(Region)
                VisibleEvents[Region] = true
            end)
            RegionStateObject.RegionHidden:Connect(function(Region)
                HiddenEvents[Region] = true
            end)

            RegionStateObject:UpdateVisibleRegions(Vector3.new(0, 0, 0))
            task.wait()
            expect(VisibleEvents["Region1"]).to.equal(true)
            expect(VisibleEvents["Region2"]).to.equal(true)
            expect(VisibleEvents["Region3"]).to.equal(true)
            expect(HiddenEvents["Region1"]).to.equal(nil)
            expect(HiddenEvents["Region2"]).to.equal(nil)
            expect(HiddenEvents["Region3"]).to.equal(nil)
            expect(RegionStateObject:IsRegionVisible("Region1")).to.equal(true)
            expect(RegionStateObject:IsRegionVisible("Region2")).to.equal(true)
            expect(RegionStateObject:IsRegionVisible("Region3")).to.equal(true)

            VisibleEvents, HiddenEvents = {}, {}
            RegionStateObject:UpdateVisibleRegions(Vector3.new(0, 4, 0))
            task.wait()
            expect(VisibleEvents["Region1"]).to.equal(nil)
            expect(VisibleEvents["Region2"]).to.equal(nil)
            expect(VisibleEvents["Region3"]).to.equal(nil)
            expect(HiddenEvents["Region1"]).to.equal(nil)
            expect(HiddenEvents["Region2"]).to.equal(nil)
            expect(HiddenEvents["Region3"]).to.equal(nil)
            expect(RegionStateObject:IsRegionVisible("Region1")).to.equal(true)
            expect(RegionStateObject:IsRegionVisible("Region2")).to.equal(true)
            expect(RegionStateObject:IsRegionVisible("Region3")).to.equal(true)

            VisibleEvents, HiddenEvents = {}, {}
            RegionStateObject:UpdateVisibleRegions(Vector3.new(0, 0, 4))
            task.wait()
            expect(VisibleEvents["Region1"]).to.equal(nil)
            expect(VisibleEvents["Region2"]).to.equal(nil)
            expect(VisibleEvents["Region3"]).to.equal(nil)
            expect(HiddenEvents["Region1"]).to.equal(nil)
            expect(HiddenEvents["Region2"]).to.equal(nil)
            expect(HiddenEvents["Region3"]).to.equal(true)
            expect(RegionStateObject:IsRegionVisible("Region1")).to.equal(true)
            expect(RegionStateObject:IsRegionVisible("Region2")).to.equal(true)
            expect(RegionStateObject:IsRegionVisible("Region3")).to.equal(false)

            VisibleEvents, HiddenEvents = {}, {}
            RegionStateObject:UpdateVisibleRegions(Vector3.new(0, 0, 6))
            task.wait()
            expect(VisibleEvents["Region1"]).to.equal(nil)
            expect(VisibleEvents["Region2"]).to.equal(nil)
            expect(VisibleEvents["Region3"]).to.equal(true)
            expect(HiddenEvents["Region1"]).to.equal(nil)
            expect(HiddenEvents["Region2"]).to.equal(true)
            expect(HiddenEvents["Region3"]).to.equal(nil)
            expect(RegionStateObject:IsRegionVisible("Region1")).to.equal(true)
            expect(RegionStateObject:IsRegionVisible("Region2")).to.equal(false)
            expect(RegionStateObject:IsRegionVisible("Region3")).to.equal(true)

            VisibleEvents, HiddenEvents = {}, {}
            RegionStateObject:UpdateVisibleRegions(Vector3.new(0, 0, 10))
            task.wait()
            expect(VisibleEvents["Region1"]).to.equal(nil)
            expect(VisibleEvents["Region2"]).to.equal(nil)
            expect(VisibleEvents["Region3"]).to.equal(nil)
            expect(HiddenEvents["Region1"]).to.equal(true)
            expect(HiddenEvents["Region2"]).to.equal(nil)
            expect(HiddenEvents["Region3"]).to.equal(true)
            expect(RegionStateObject:IsRegionVisible("Region1")).to.equal(false)
            expect(RegionStateObject:IsRegionVisible("Region2")).to.equal(false)
            expect(RegionStateObject:IsRegionVisible("Region3")).to.equal(false)
        end)

        it("should build regions from parts", function()
            local InstanceTree = Instance.new("Folder")
            InstanceTree.Name = "Regions"
            local Region4 = Instance.new("Model", InstanceTree)
            Region4.Name = "Region4"
            local BasePart = Instance.new("Part", Region4)
            BasePart.CFrame = CFrame.new(0, 4, 0)
            BasePart.Size = Vector3.new(2, 2, 2)
                    
            RegionStateObject:InsertRegionsFromInstance(InstanceTree)
            expect(RegionStateObject:IsInRegion("Region4", Vector3.new(0, 1, 0))).to.equal(false)
            expect(RegionStateObject:IsInRegion("Region4", Vector3.new(0, 3, 0))).to.equal(true)
        end)
    end)
end

--Tests the BufferedRegionState class.
--!strict

local Event = require(game:GetService("ReplicatedStorage"):WaitForChild("RegionCulling"):WaitForChild("Event"))
local BufferedRegionState = require(game:GetService("ReplicatedStorage"):WaitForChild("RegionCulling"):WaitForChild("State"):WaitForChild("BufferedRegionState"))

return function()
    describe("A buffered region state", function()
        local TestRegionState = nil
        local RegionStateObject = nil
        local VisibleEvents, HiddenEvents = {} :: {[string]: number}, {} :: {[string]: number}
        beforeEach(function()
            TestRegionState = {
                RegionVisible = Event.new() :: Event.Event<string>,
                RegionHidden = Event.new() :: Event.Event<string>,
            }
            RegionStateObject = BufferedRegionState.new(TestRegionState :: any)
            RegionStateObject.HiddenRegionTimeout = 0.1

            VisibleEvents, HiddenEvents = {}, {}
            RegionStateObject.RegionVisible:Connect(function(Region)
                VisibleEvents[Region] = (VisibleEvents[Region] or 0) + 1
            end)
            RegionStateObject.RegionHidden:Connect(function(Region)
                HiddenEvents[Region] = (HiddenEvents[Region] or 0) + 1
            end)
        end)
    
        it("should show new regions instantly.", function()
            TestRegionState.RegionVisible:Fire("Region1")
            TestRegionState.RegionVisible:Fire("Region2")
            task.wait()
            expect(RegionStateObject:GetCurrentVisibleRegions()[1]).to.equal("Region1")
            expect(RegionStateObject:GetCurrentVisibleRegions()[2]).to.equal("Region2")
            expect(VisibleEvents["Region1"]).to.equal(1)
            expect(VisibleEvents["Region2"]).to.equal(1)
            expect(RegionStateObject:IsRegionVisible("Region1")).to.equal(true)
            expect(RegionStateObject:IsRegionVisible("Region2")).to.equal(true)
        end)
    
        it("should delay hidden events.", function()
            TestRegionState.RegionVisible:Fire("Region1")
            task.wait()
            expect(RegionStateObject:GetCurrentVisibleRegions()[1]).to.equal("Region1")
            expect(VisibleEvents["Region1"]).to.equal(1)
            expect(HiddenEvents["Region1"]).to.equal(nil)
            TestRegionState.RegionHidden:Fire("Region1")
            expect(RegionStateObject:IsRegionVisible("Region1")).to.equal(true)
            task.wait(0.2)
            expect(RegionStateObject:GetCurrentVisibleRegions()[1]).to.equal(nil)
            expect(HiddenEvents["Region1"]).to.equal(1)
            expect(RegionStateObject:IsRegionVisible("Region1")).to.equal(false)
        end)
    
        it("should ignore hidden events when made visible.", function()
            TestRegionState.RegionVisible:Fire("Region1")
            task.wait()
            expect(RegionStateObject:GetCurrentVisibleRegions()[1]).to.equal("Region1")
            expect(VisibleEvents["Region1"]).to.equal(1)
            expect(HiddenEvents["Region1"]).to.equal(nil)
            TestRegionState.RegionHidden:Fire("Region1")
            TestRegionState.RegionVisible:Fire("Region1")
            expect(RegionStateObject:IsRegionVisible("Region1")).to.equal(true)
            task.wait(0.2)
            expect(RegionStateObject:GetCurrentVisibleRegions()[1]).to.equal("Region1")
            expect(VisibleEvents["Region1"]).to.equal(1)
            expect(HiddenEvents["Region1"]).to.equal(nil)
            expect(RegionStateObject:IsRegionVisible("Region1")).to.equal(true)
        end)
    end)
end
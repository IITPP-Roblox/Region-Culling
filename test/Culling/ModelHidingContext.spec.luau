--Tests the ModelHidingContext class.
--!strict

local ModelHidingContext = require(game:GetService("ReplicatedStorage"):WaitForChild("RegionCulling"):WaitForChild("Culling"):WaitForChild("ModelHidingContext"))

return function()
    describe("A model hiding context", function()
        local Model, ModelHidingContextObject = nil, nil
        local Part, SurfaceGui, Constraint, Dialog = nil, nil, nil, nil
        beforeEach(function()
            Model = Instance.new("Model")
            ModelHidingContextObject = ModelHidingContext.new(Model)
            Part = Instance.new("Part", Model)
            SurfaceGui = Instance.new("SurfaceGui", Model)
            SurfaceGui.MaxDistance = 100
            Constraint = Instance.new("RopeConstraint", Model)
            Constraint.Visible = true
            Dialog = Instance.new("Dialog", Model)
            task.wait()
        end)

        it("should hide instances.", function()
            expect(ModelHidingContextObject:HideModel(2)).to.equal(0)
            expect(Part.LocalTransparencyModifier).to.equal(1)
            expect(math.abs(SurfaceGui.MaxDistance - 0.0001) < 0.00001).to.equal(true)
            expect(SurfaceGui:GetAttribute("OriginalMaxDistance")).to.equal(100)
            expect(Constraint.Visible).to.equal(true)
            expect(Constraint:GetAttribute("WasHidden")).to.equal(nil)
            expect(Dialog.InUse).to.equal(false)
            expect(Dialog:GetAttribute("WasHidden")).to.equal(nil)

            expect(ModelHidingContextObject:HideModel(5)).to.equal(3)
            expect(Part.LocalTransparencyModifier).to.equal(1)
            expect(math.abs(SurfaceGui.MaxDistance - 0.0001) < 0.00001).to.equal(true)
            expect(SurfaceGui:GetAttribute("OriginalMaxDistance")).to.equal(100)
            expect(Constraint.Visible).to.equal(false)
            expect(Constraint:GetAttribute("WasHidden")).to.equal(true)
            expect(Dialog.InUse).to.equal(true)
            expect(Dialog:GetAttribute("WasHidden")).to.equal(true)

            expect(ModelHidingContextObject:HideModel(5)).to.equal(5)
        end)

        it("should show instances.", function()
            ModelHidingContextObject:HideModel(4)

            expect(ModelHidingContextObject:ShowModel(2)).to.equal(0)
            expect(Part.LocalTransparencyModifier).to.equal(0)
            expect(SurfaceGui.MaxDistance).to.equal(100)
            expect(SurfaceGui:GetAttribute("OriginalMaxDistance")).to.equal(nil)
            expect(Constraint.Visible).to.equal(false)
            expect(Constraint:GetAttribute("WasHidden")).to.equal(true)
            expect(Dialog.InUse).to.equal(true)
            expect(Dialog:GetAttribute("WasHidden")).to.equal(true)

            expect(ModelHidingContextObject:ShowModel(2)).to.equal(0)
            expect(Part.LocalTransparencyModifier).to.equal(0)
            expect(SurfaceGui.MaxDistance).to.equal(100)
            expect(SurfaceGui:GetAttribute("OriginalMaxDistance")).to.equal(nil)
            expect(Constraint.Visible).to.equal(true)
            expect(Constraint:GetAttribute("WasHidden")).to.equal(nil)
            expect(Dialog.InUse).to.equal(false)
            expect(Dialog:GetAttribute("WasHidden")).to.equal(nil)
            
            expect(ModelHidingContextObject:ShowModel(5)).to.equal(5)
        end)

        it("should hide new instances when hidden.", function()
            ModelHidingContextObject:HideModel(2)
            local NewPart = Instance.new("Part", Model)
            task.wait()
            expect(NewPart.LocalTransparencyModifier).to.equal(1)
        end)

        it("should show removed instances when hidden.", function()
            ModelHidingContextObject:HideModel(2)
            Part.Parent = nil
            task.wait()
            expect(Part.LocalTransparencyModifier).to.equal(0)
        end)
    end)
end
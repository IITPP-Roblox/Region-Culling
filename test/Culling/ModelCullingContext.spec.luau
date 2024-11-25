--Tests the ModelCullingContext class.
--!strict

local ModelCullingContext = require(game:GetService("ReplicatedStorage"):WaitForChild("RegionCulling"):WaitForChild("Culling"):WaitForChild("ModelCullingContext"))

return function()
    describe("A model culling context", function()
        local HiddenGeometry, Model, ModelCullingContextObject = nil, nil, nil
        beforeEach(function()
            HiddenGeometry = Instance.new("Folder")
            Model = Instance.new("Model")
            for i = 1, 20 do
                Instance.new("Part", Model).Name = tostring(i)
            end
            ModelCullingContextObject = ModelCullingContext.new(Model, {HiddenGeometry = HiddenGeometry} :: any)
        end)

        it("should flatten models without clustering.", function()
            ModelCullingContextObject:EnableFlattening()
            local StaticParts = Model:WaitForChild("StaticParts") :: Model
            ModelCullingContextObject:FlattenModel()

            expect(#Model:GetChildren()).to.equal(1)
            expect(#StaticParts:GetChildren()).to.equal(20)
        end)

        it("should flatten models with clustering.", function()
            ModelCullingContextObject:EnableFlattening():EnableClustering(5)
            local StaticParts = Model:WaitForChild("StaticParts") :: Model
            ModelCullingContextObject:FlattenModel()

            expect(#Model:GetChildren()).to.equal(1)
            expect(#StaticParts:GetChildren()).to.equal(4)
            expect(#StaticParts:GetChildren()[1]:GetChildren()).to.equal(5)
            expect(#StaticParts:GetChildren()[2]:GetChildren()).to.equal(5)
            expect(#StaticParts:GetChildren()[3]:GetChildren()).to.equal(5)
            expect(#StaticParts:GetChildren()[4]:GetChildren()).to.equal(5)
        end)

        it("should flatten models with clustering and filters.", function()
            ModelCullingContextObject:EnableFlattening():EnableClustering(5)
            ModelCullingContextObject:AddFlatteningFilter(function(Child)
                return string.len(Child.Name) ~= 2, "Name has 2 characters"
            end)
            local StaticParts = Model:WaitForChild("StaticParts") :: Model
            ModelCullingContextObject:FlattenModel()

            expect(#Model:GetChildren()).to.equal(12)
            expect(#StaticParts:GetChildren()).to.equal(5) --Parts 6 to 9 (nice) aren't enough to cluster.
            expect(#StaticParts:WaitForChild("PartCluster"):GetChildren()).to.equal(5)
        end)

        it("should flatten Humanoids together.", function()
            local SubModel1 = Instance.new("Model", Model)
            SubModel1.Name = "Character1"
            for i = 1, 8 do
                Instance.new("Part", SubModel1)
            end
            Instance.new("Humanoid", SubModel1)

            local SubModel2 = Instance.new("Model", Model)
            local SubModel3 = Instance.new("Model", SubModel2)
            SubModel3.Name = "Character2"
            for i = 1, 9 do
                Instance.new("Part", SubModel3)
            end
            Instance.new("Humanoid", SubModel3)

            ModelCullingContextObject:EnableFlattening(15):EnableClustering(5)
            local StaticParts = Model:WaitForChild("StaticParts") :: Model
            ModelCullingContextObject:FlattenModel()

            expect(#Model:GetChildren()).to.equal(2)
            expect(#StaticParts:GetChildren()).to.equal(6)
            expect(#StaticParts:WaitForChild("Character1"):GetChildren()).to.equal(9)
            expect(#StaticParts:WaitForChild("Character2"):GetChildren()).to.equal(10)
        end)

        it("should hide models together when not flattened.", function()
            expect(ModelCullingContextObject:HideModel(15)).to.equal(0)
            expect(#Model:GetChildren()).to.equal(20)
            expect(Model.Parent).to.equal(HiddenGeometry)
        end)

        it("should hide models gradually when flattened.", function()
            ModelCullingContextObject:EnableFlattening()
            ModelCullingContextObject:FlattenModel()

            expect(ModelCullingContextObject:HideModel(15)).to.equal(0)
            expect(#Model:GetDescendants()).to.equal(6)
            expect(#Model:WaitForChild("StaticParts"):GetDescendants()).to.equal(5)
            expect(Model.Parent).to.equal(nil)

            expect(ModelCullingContextObject:HideModel(15)).to.equal(10)
            expect(#Model:WaitForChild("StaticParts"):GetDescendants()).to.equal(0)
            expect(#Model:GetDescendants()).to.equal(1)
            expect(Model.Parent).to.equal(HiddenGeometry)
        end)

        it("should show models together when not flattened.", function()
            ModelCullingContextObject:HideModel(50)

            expect(ModelCullingContextObject:ShowModel(15)).to.equal(0)
            expect(#Model:GetChildren()).to.equal(20)
            expect(Model.Parent).to.equal(nil)
        end)

        it("should show models gradually when flattened.", function()
            ModelCullingContextObject:EnableFlattening()
            ModelCullingContextObject:FlattenModel()
            ModelCullingContextObject:HideModel(50)

            expect(ModelCullingContextObject:ShowModel(15)).to.equal(0)
            expect(#Model:GetDescendants()).to.equal(16)
            expect(#Model:WaitForChild("StaticParts"):GetDescendants()).to.equal(15)
            expect(Model.Parent).to.equal(nil)

            expect(ModelCullingContextObject:ShowModel(15)).to.equal(10)
            expect(#Model:GetDescendants()).to.equal(21)
            expect(#Model:WaitForChild("StaticParts"):GetDescendants()).to.equal(20)
            expect(Model.Parent).to.equal(nil)
        end)

        it("should flatten models with clustering while hidden and properly show them again.", function()
            ModelCullingContextObject:HideModel(50)
            ModelCullingContextObject:EnableFlattening():EnableClustering(5)
            local StaticParts = Model:WaitForChild("StaticParts") :: Model
            ModelCullingContextObject:FlattenModel()

            expect(#Model:GetChildren()).to.equal(1)
            expect(#StaticParts:GetChildren()).to.equal(0)
            ModelCullingContextObject:ShowModel(50)
            expect(#StaticParts:GetChildren()).to.equal(4)
            expect(#StaticParts:GetChildren()[1]:GetChildren()).to.equal(5)
            expect(#StaticParts:GetChildren()[2]:GetChildren()).to.equal(5)
            expect(#StaticParts:GetChildren()[3]:GetChildren()).to.equal(5)
            expect(#StaticParts:GetChildren()[4]:GetChildren()).to.equal(5)
        end)

        it("should show summaries of unflattened models.", function()
            local Summary = ModelCullingContextObject:GetSummary()
            expect(Summary.FlattenedParts).to.equal(0)
            expect(Summary.UnflattenedParts).to.equal(20)
            expect(#Summary.Issues).to.equal(0)

            ModelCullingContextObject:HideModel(50)
            Summary = ModelCullingContextObject:GetSummary()
            expect(Summary.FlattenedParts).to.equal(0)
            expect(Summary.UnflattenedParts).to.equal(20)
            expect(#Summary.Issues).to.equal(0)
        end)

        it("should show summaries of flattened models.", function()
            ModelCullingContextObject:AddFlatteningFilter(function(Child)
                return Child.Name ~= "10" and Child.Name ~= "12", "Name is filtered"
            end)
            ModelCullingContextObject:EnableFlattening():FlattenModel()

            local Summary = ModelCullingContextObject:GetSummary()
            expect(Summary.FlattenedParts).to.equal(18)
            expect(Summary.UnflattenedParts).to.equal(2)
            expect(#Summary.Issues).to.equal(2)
            expect(Summary.Issues[1].Instance.Name).to.equal("10")
            expect(Summary.Issues[1].Issues[1]).to.equal("Name is filtered")
            expect(Summary.Issues[2].Instance.Name).to.equal("12")
            expect(Summary.Issues[2].Issues[1]).to.equal("Name is filtered")

            ModelCullingContextObject:HideModel(15)
            Summary = ModelCullingContextObject:GetSummary()
            expect(Summary.FlattenedParts).to.equal(18)
            expect(Summary.UnflattenedParts).to.equal(2)
            expect(#Summary.Issues).to.equal(2)
            expect(Summary.Issues[1].Instance.Name).to.equal("10")
            expect(Summary.Issues[1].Issues[1]).to.equal("Name is filtered")
            expect(Summary.Issues[2].Instance.Name).to.equal("12")
            expect(Summary.Issues[2].Issues[1]).to.equal("Name is filtered")
        end)

        it("should show summaries of clustered flattened models.", function()
            ModelCullingContextObject:AddFlatteningFilter(function(Child)
                return Child.Name ~= "10" and Child.Name ~= "12", "Name is filtered"
            end)
            ModelCullingContextObject:EnableClustering(5):EnableFlattening():FlattenModel()

            local Summary = ModelCullingContextObject:GetSummary()
            expect(Summary.FlattenedParts).to.equal(18)
            expect(Summary.UnflattenedParts).to.equal(2)
            expect(#Summary.Issues).to.equal(2)
            expect(Summary.Issues[1].Instance.Name).to.equal("10")
            expect(Summary.Issues[1].Issues[1]).to.equal("Name is filtered")
            expect(Summary.Issues[2].Instance.Name).to.equal("12")
            expect(Summary.Issues[2].Issues[1]).to.equal("Name is filtered")

            ModelCullingContextObject:HideModel(15)
            Summary = ModelCullingContextObject:GetSummary()
            expect(Summary.FlattenedParts).to.equal(18)
            expect(Summary.UnflattenedParts).to.equal(2)
            expect(#Summary.Issues).to.equal(2)
            expect(Summary.Issues[1].Instance.Name).to.equal("10")
            expect(Summary.Issues[1].Issues[1]).to.equal("Name is filtered")
            expect(Summary.Issues[2].Instance.Name).to.equal("12")
            expect(Summary.Issues[2].Issues[1]).to.equal("Name is filtered")
        end)
    end)
end
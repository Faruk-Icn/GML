local WeightedRandom = {}
WeightedRandom.__index = WeightedRandom

function WeightedRandom.New(Generator: Random?)
	assert(Generator == nil or typeof(Generator) == "Random", "Generator must be a Random")
	return setmetatable({ Entries = {}, Generator = Generator or Random.new(), Total = 0 }, WeightedRandom)
end

function WeightedRandom:Add(Value: any, Weight: number)
	assert(type(Weight) == "number" and Weight > 0 and Weight < math.huge, "Weight must be a positive finite number")
	assert(self.Total + Weight < math.huge, "Total weight is too large")
	table.insert(self.Entries, { Value = Value, Weight = Weight })
	self.Total += Weight
	return self
end

function WeightedRandom:Roll(): (any, number?)
	if #self.Entries == 0 then
		return nil, nil
	end
	local Target = self.Generator:NextNumber(0, self.Total)
	local Sum = 0
	for Index, Entry in ipairs(self.Entries) do
		Sum += Entry.Weight
		if Target < Sum or Index == #self.Entries then
			return Entry.Value, Index
		end
	end
	return nil, nil
end

function WeightedRandom:Clear()
	self.Entries = {}
	self.Total = 0
end

return WeightedRandom

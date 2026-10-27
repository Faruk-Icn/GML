local Table = {}

local function Copy(Value: any, Seen: { [any]: any }): any
	if type(Value) ~= "table" then
		return Value
	end
	if Seen[Value] then
		return Seen[Value]
	end
	local Result = {}
	Seen[Value] = Result
	for Key, Item in pairs(Value) do
		Result[Copy(Key, Seen)] = Copy(Item, Seen)
	end
	local Meta = getmetatable(Value)
	if type(Meta) == "table" then
		return setmetatable(Result, Meta)
	end
	return Result
end

function Table.DeepCopy(Value: any): any
	return Copy(Value, {})
end

function Table.Merge(Left: { [any]: any }, Right: { [any]: any }): { [any]: any }
	local Result = Table.DeepCopy(Left)
	for Key, Value in pairs(Right) do
		if type(Value) == "table" and type(Result[Key]) == "table" then
			Result[Key] = Table.Merge(Result[Key], Value)
		else
			Result[Key] = Table.DeepCopy(Value)
		end
	end
	return Result
end

function Table.Count(Value: { [any]: any }): number
	local Total = 0
	for _ in pairs(Value) do
		Total += 1
	end
	return Total
end

return Table

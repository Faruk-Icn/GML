local ObjectPool = {}
ObjectPool.__index = ObjectPool

local function DefaultDispose(Item: any)
	if typeof(Item) == "Instance" then
		Item:Destroy()
	elseif type(Item) == "table" and type(Item.Destroy) == "function" then
		Item:Destroy()
	end
end

function ObjectPool.New(Create: () -> any, Reset: ((any) -> ())?, MaxAvailable: number?, Dispose: ((any) -> ())?)
	assert(type(Create) == "function", "Create must be a function")
	assert(Reset == nil or type(Reset) == "function", "Reset must be a function")
	assert(Dispose == nil or type(Dispose) == "function", "Dispose must be a function")
	local Maximum = MaxAvailable or math.huge
	assert(type(Maximum) == "number" and Maximum >= 0 and (Maximum == math.huge or Maximum % 1 == 0), "MaxAvailable must be a non-negative integer")
	return setmetatable({
		Create = Create,
		Reset = Reset,
		Dispose = Dispose or DefaultDispose,
		MaxAvailable = Maximum,
		Available = {},
		InUse = {},
		Destroyed = false,
	}, ObjectPool)
end

function ObjectPool:Acquire(): any
	assert(not self.Destroyed, "ObjectPool has been destroyed")
	local Item = table.remove(self.Available)
	if Item == nil then
		Item = self.Create()
		assert(Item ~= nil, "Create must return an item")
	end
	self.InUse[Item] = true
	return Item
end

function ObjectPool:Release(Item: any): boolean
	assert(not self.Destroyed, "ObjectPool has been destroyed")
	if not self.InUse[Item] then
		return false
	end
	if self.Reset then
		self.Reset(Item)
	end
	self.InUse[Item] = nil
	if #self.Available < self.MaxAvailable then
		table.insert(self.Available, Item)
	else
		self.Dispose(Item)
	end
	return true
end

function ObjectPool:Destroy()
	if self.Destroyed then
		return
	end
	self.Destroyed = true
	for _, Item in ipairs(self.Available) do
		self.Dispose(Item)
	end
	for Item in pairs(self.InUse) do
		self.Dispose(Item)
	end
	self.Available = {}
	self.InUse = {}
end

return ObjectPool

local Cleanup = {}
Cleanup.__index = Cleanup

local function Dispose(Item: any, Method: string?)
	if Method then
		Item[Method](Item)
	elseif typeof(Item) == "RBXScriptConnection" then
		Item:Disconnect()
	elseif typeof(Item) == "Instance" then
		Item:Destroy()
	elseif type(Item) == "thread" then
		task.cancel(Item)
	elseif type(Item) == "function" then
		Item()
	elseif type(Item) == "table" then
		local Callback = Item.Destroy or Item.Disconnect or Item.Cancel
		assert(type(Callback) == "function", "Item has no cleanup method")
		Callback(Item)
	else
		error("Unsupported cleanup item")
	end
end

function Cleanup.New()
	return setmetatable({ Items = {}, Destroyed = false }, Cleanup)
end

function Cleanup:Add(Item: any, Method: string?): any
	assert(not self.Destroyed, "Cleanup has been destroyed")
	assert(Method == nil or type(Method) == "string", "Method must be a string")
	table.insert(self.Items, { Item = Item, Method = Method })
	return Item
end

function Cleanup:Remove(Item: any): boolean
	for Index = #self.Items, 1, -1 do
		if self.Items[Index].Item == Item then
			table.remove(self.Items, Index)
			return true
		end
	end
	return false
end

function Cleanup:Clean()
	for Index = #self.Items, 1, -1 do
		local Entry = self.Items[Index]
		self.Items[Index] = nil
		local Success, Result = pcall(Dispose, Entry.Item, Entry.Method)
		if not Success then
			warn("[GML.Cleanup] " .. tostring(Result))
		end
	end
end

function Cleanup:Destroy()
	if self.Destroyed then
		return
	end
	self.Destroyed = true
	self:Clean()
end

return Cleanup

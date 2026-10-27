local AttributeObserver = {}
AttributeObserver.__index = AttributeObserver

function AttributeObserver.New(Target: Instance)
	assert(typeof(Target) == "Instance", "Target must be an Instance")
	return setmetatable({ Target = Target, Connections = {}, Destroyed = false }, AttributeObserver)
end

function AttributeObserver:Watch(Name: string, Callback: (any, any) -> (), FireImmediately: boolean?)
	assert(not self.Destroyed, "AttributeObserver has been destroyed")
	assert(type(Name) == "string", "Name must be a string")
	assert(type(Callback) == "function", "Callback must be a function")
	local Previous = self.Target:GetAttribute(Name)
	local Connection = self.Target:GetAttributeChangedSignal(Name):Connect(function()
		local Current = self.Target:GetAttribute(Name)
		local Old = Previous
		Previous = Current
		Callback(Current, Old)
	end)
	table.insert(self.Connections, Connection)
	if FireImmediately then
		Callback(Previous, nil)
	end
	return Connection
end

function AttributeObserver:Destroy()
	if self.Destroyed then
		return
	end
	self.Destroyed = true
	for _, Connection in ipairs(self.Connections) do
		Connection:Disconnect()
	end
	self.Connections = {}
end

return AttributeObserver

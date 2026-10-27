local Signal = {}
Signal.__index = Signal

function Signal.New()
	return setmetatable({ Listeners = {}, Waiting = {}, Destroyed = false }, Signal)
end

function Signal:Connect(Callback: (...any) -> ())
	assert(not self.Destroyed, "Signal has been destroyed")
	assert(type(Callback) == "function", "Callback must be a function")
	local Connection = { Connected = true }
	local Listeners = self.Listeners
	function Connection:Disconnect()
		if self.Connected then
			self.Connected = false
			Listeners[self] = nil
		end
	end
	Listeners[Connection] = Callback
	return Connection
end

function Signal:Once(Callback: (...any) -> ())
	local Connection
	Connection = self:Connect(function(...)
		Connection:Disconnect()
		Callback(...)
	end)
	return Connection
end

function Signal:Fire(...)
	assert(not self.Destroyed, "Signal has been destroyed")
	local Arguments = table.pack(...)
	for Connection, Callback in pairs(self.Listeners) do
		if Connection.Connected then
			task.spawn(Callback, table.unpack(Arguments, 1, Arguments.n))
		end
	end
	for Thread in pairs(self.Waiting) do
		self.Waiting[Thread] = nil
		task.spawn(Thread, table.unpack(Arguments, 1, Arguments.n))
	end
end

function Signal:Wait(): ...any
	assert(not self.Destroyed, "Signal has been destroyed")
	local Thread = coroutine.running()
	self.Waiting[Thread] = true
	return coroutine.yield()
end

function Signal:Destroy()
	if self.Destroyed then
		return
	end
	self.Destroyed = true
	for Connection in pairs(self.Listeners) do
		Connection:Disconnect()
	end
	for Thread in pairs(self.Waiting) do
		self.Waiting[Thread] = nil
		task.spawn(Thread)
	end
end

return Signal

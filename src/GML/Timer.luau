local Timer = {}
Timer.__index = Timer

function Timer.New(Seconds: number, Callback: () -> (), Repeat: boolean?)
	assert(type(Seconds) == "number" and Seconds > 0 and Seconds < math.huge, "Seconds must be a positive finite number")
	assert(type(Callback) == "function", "Callback must be a function")
	return setmetatable({
		Seconds = Seconds,
		Callback = Callback,
		Repeat = Repeat == true,
		Running = false,
		Deadline = 0,
		Thread = nil,
		Generation = 0,
		Destroyed = false,
	}, Timer)
end

function Timer:Start()
	assert(not self.Destroyed, "Timer has been destroyed")
	self:Stop()
	self.Running = true
	self.Deadline = os.clock() + self.Seconds
	local Generation = self.Generation
	self.Thread = task.delay(self.Seconds, function()
		if self.Generation ~= Generation or not self.Running then
			return
		end
		self.Running = false
		self.Thread = nil
		self.Callback()
		if self.Repeat and self.Generation == Generation and not self.Destroyed then
			self:Start()
		end
	end)
	return self
end

function Timer:Remaining(): number
	return if self.Running then math.max(0, self.Deadline - os.clock()) else 0
end

function Timer:Stop()
	self.Generation += 1
	self.Running = false
	if self.Thread then
		pcall(task.cancel, self.Thread)
		self.Thread = nil
	end
end

function Timer:Destroy()
	if self.Destroyed then
		return
	end
	self.Destroyed = true
	self:Stop()
end

return Timer

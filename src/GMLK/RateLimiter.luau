local RateLimiter = {}
RateLimiter.__index = RateLimiter

local DefaultKey = {}
local BoundFunctions = setmetatable({}, { __mode = "k" })
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local function CheckPositive(Value: number, Name: string)
	assert(type(Value) == "number" and Value > 0 and Value < math.huge, Name .. " must be a positive finite number")
end

local function CreateBinding(Limiter, DisconnectRemote: () -> ())
	local Leaving = Players.PlayerRemoving:Connect(function(Player)
		Limiter:Reset(Player.UserId)
	end)
	local Binding = { Connected = true }
	function Binding:Disconnect()
		if not self.Connected then
			return
		end
		self.Connected = false
		DisconnectRemote()
		Leaving:Disconnect()
	end
	return Binding
end

function RateLimiter.New(Capacity: number, WindowSeconds: number, Clock: (() -> number)?)
	CheckPositive(Capacity, "Capacity")
	assert(Capacity >= 1 and Capacity % 1 == 0, "Capacity must be a positive integer")
	CheckPositive(WindowSeconds, "WindowSeconds")
	assert(type(Clock) == "function" or Clock == nil, "Clock must be a function")
	local Self = setmetatable({}, RateLimiter)
	Self.Capacity = Capacity
	Self.RefillRate = Capacity / WindowSeconds
	Self.Clock = Clock or os.clock
	Self.Buckets = {}
	return Self
end

function RateLimiter:_GetBucket(Key: string | number?)
	local BucketKey = if Key == nil then DefaultKey else Key
	assert(type(BucketKey) == "string" or type(BucketKey) == "number" or BucketKey == DefaultKey, "Key must be a string or number")
	assert(type(BucketKey) ~= "number" or BucketKey == BucketKey, "Key cannot be NaN")
	local Now = self.Clock()
	local Bucket = self.Buckets[BucketKey]
	if not Bucket then
		Bucket = { Tokens = self.Capacity, UpdatedAt = Now }
		self.Buckets[BucketKey] = Bucket
	else
		local Elapsed = math.max(0, Now - Bucket.UpdatedAt)
		Bucket.Tokens = math.min(self.Capacity, Bucket.Tokens + Elapsed * self.RefillRate)
		Bucket.UpdatedAt = Now
	end
	return Bucket
end

function RateLimiter:Allow(Key: string | number?, Cost: number?): (boolean, number, number)
	local Amount = Cost or 1
	CheckPositive(Amount, "Cost")
	assert(Amount <= self.Capacity, "Cost cannot exceed Capacity")
	local Bucket = self:_GetBucket(Key)
	if Bucket.Tokens >= Amount then
		Bucket.Tokens -= Amount
		return true, 0, Bucket.Tokens
	end
	return false, (Amount - Bucket.Tokens) / self.RefillRate, Bucket.Tokens
end

function RateLimiter:Remaining(Key: string | number?): number
	return self:_GetBucket(Key).Tokens
end

function RateLimiter:Reset(Key: string | number?)
	local BucketKey = if Key == nil then DefaultKey else Key
	assert(type(BucketKey) == "string" or type(BucketKey) == "number" or BucketKey == DefaultKey, "Key must be a string or number")
	self.Buckets[BucketKey] = nil
end

function RateLimiter:ResetAll()
	self.Buckets = {}
end

function RateLimiter:BindEvent(Remote: RemoteEvent | UnreliableRemoteEvent, Handler: (Player, ...any) -> (), Rejected: ((Player, number) -> ())?)
	assert(RunService:IsServer(), "BindEvent can only be called on the server")
	assert(typeof(Remote) == "Instance" and (Remote:IsA("RemoteEvent") or Remote:IsA("UnreliableRemoteEvent")), "Remote must be a RemoteEvent or UnreliableRemoteEvent")
	assert(type(Handler) == "function", "Handler must be a function")
	assert(Rejected == nil or type(Rejected) == "function", "Rejected must be a function")
	local Connection = Remote.OnServerEvent:Connect(function(Player, ...)
		local Allowed, RetryAfter = self:Allow(Player.UserId)
		if Allowed then
			Handler(Player, ...)
		elseif Rejected then
			Rejected(Player, RetryAfter)
		end
	end)
	return CreateBinding(self, function()
		Connection:Disconnect()
	end)
end

function RateLimiter:BindFunction(Remote: RemoteFunction, Handler: (Player, ...any) -> ...any)
	assert(RunService:IsServer(), "BindFunction can only be called on the server")
	assert(typeof(Remote) == "Instance" and Remote:IsA("RemoteFunction"), "Remote must be a RemoteFunction")
	assert(type(Handler) == "function", "Handler must be a function")
	assert(BoundFunctions[Remote] == nil, "RemoteFunction is already bound by GMLK")
	local function Invoke(Player, ...)
		local Allowed, RetryAfter = self:Allow(Player.UserId)
		if not Allowed then
			return nil, RetryAfter
		end
		return Handler(Player, ...)
	end
	BoundFunctions[Remote] = Invoke
	Remote.OnServerInvoke = Invoke
	return CreateBinding(self, function()
		if BoundFunctions[Remote] == Invoke then
			BoundFunctions[Remote] = nil
			Remote.OnServerInvoke = nil
		end
	end)
end

return RateLimiter

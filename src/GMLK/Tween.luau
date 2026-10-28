local TweenService = game:GetService("TweenService")

local Tween = {}
Tween.__index = Tween

function Tween.New()
	return setmetatable({ Active = {}, Destroyed = false }, Tween)
end

function Tween:Play(Target: Instance, Info: TweenInfo, Properties: { [string]: any })
	assert(not self.Destroyed, "Tween manager has been destroyed")
	self:Cancel(Target)
	local Animation = TweenService:Create(Target, Info, Properties)
	local Entry = { Animation = Animation, Connection = nil }
	self.Active[Target] = Entry
	Entry.Connection = Animation.Completed:Connect(function()
		if self.Active[Target] == Entry then
			self.Active[Target] = nil
		end
		Entry.Connection:Disconnect()
	end)
	Animation:Play()
	return Animation
end

function Tween:Cancel(Target: Instance): boolean
	local Entry = self.Active[Target]
	if not Entry then
		return false
	end
	self.Active[Target] = nil
	Entry.Connection:Disconnect()
	Entry.Animation:Cancel()
	return true
end

function Tween:CancelAll()
	local Targets = {}
	for Target in pairs(self.Active) do
		table.insert(Targets, Target)
	end
	for _, Target in ipairs(Targets) do
		self:Cancel(Target)
	end
end

function Tween:Destroy()
	if self.Destroyed then
		return
	end
	self.Destroyed = true
	self:CancelAll()
end

return Tween

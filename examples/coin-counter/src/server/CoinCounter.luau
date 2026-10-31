local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GMLK = require(ReplicatedStorage.Modules.Library.GMLK)

local CoinCounter = { Priority = 10 }

function CoinCounter:Init()
	self.Balances = {}
	self.Limiter = GMLK.RateLimiter.New(3, 5)
	self.Remote = ReplicatedStorage.Remotes.AddCoin
end

function CoinCounter:Start()
	local Handler = GMLK.RemoteGuard.Wrap({ GMLK.RemoteGuard.Number(1, 1) }, function(Player, Amount)
		local Balance = (self.Balances[Player.UserId] or 0) + Amount
		self.Balances[Player.UserId] = Balance
		return Balance
	end)

	self.Binding = self.Limiter:BindFunction(self.Remote, Handler)
	self.Leaving = Players.PlayerRemoving:Connect(function(Player)
		self.Balances[Player.UserId] = nil
	end)
end

return CoinCounter

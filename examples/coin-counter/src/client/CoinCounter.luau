local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GMLK = require(ReplicatedStorage.Modules.Library.GMLK)

local CoinCounter = { Priority = 10 }

function CoinCounter:Init()
	self.Remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("AddCoin")
end

function CoinCounter:Start()
	local Gui = Instance.new("ScreenGui")
	Gui.Name = "GMLKCoinCounter"
	Gui.ResetOnSpawn = false
	Gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local Button = Instance.new("TextButton")
	Button.Name = "AddCoin"
	Button.Size = UDim2.fromOffset(240, 52)
	Button.Position = UDim2.fromScale(0.5, 0.5)
	Button.AnchorPoint = Vector2.new(0.5, 0.5)
	Button.Text = "Add coin"
	Button.TextSize = 22
	Button.Parent = Gui

	local Status = Instance.new("TextLabel")
	Status.Name = "Status"
	Status.Size = UDim2.fromOffset(280, 44)
	Status.Position = UDim2.fromScale(0.5, 0.5)
	Status.AnchorPoint = Vector2.new(0.5, 0.5)
	Status.BackgroundTransparency = 1
	Status.Text = "Coins: 0"
	Status.TextSize = 20
	Status.Parent = Gui
	Status.Position += UDim2.fromOffset(0, 54)

	Button.Activated:Connect(function()
		task.spawn(function()
			local Success, Balance, Detail = pcall(self.Remote.InvokeServer, self.Remote, 1)
			if not Success then
				Status.Text = "Request failed"
			elseif type(Balance) == "number" then
				Status.Text = "Coins: " .. GMLK.Number.Abbreviate(Balance, 0)
			elseif type(Detail) == "number" then
				Status.Text = "Wait " .. math.ceil(Detail) .. "s"
			else
				Status.Text = tostring(Detail or "Request rejected")
			end
		end)
	end)
end

return CoinCounter

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local GML = require(Modules:WaitForChild("Library"):WaitForChild("GML"))
local ClientModules = Modules:WaitForChild("Client")

local Loader = GML.New("Client")
Loader:LoadModules(ClientModules, { IncludeDescendants = true })

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local GMLK = require(Modules:WaitForChild("Library"):WaitForChild("GMLK"))
local ClientModules = Modules:WaitForChild("Client")

local Loader = GMLK.New("Client")
Loader:LoadModules(ClientModules, { IncludeDescendants = true })

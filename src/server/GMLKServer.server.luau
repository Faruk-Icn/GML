local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local GMLK = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Library"):WaitForChild("GMLK"))
local ServerModules = ServerStorage:WaitForChild("Modules"):WaitForChild("Client")

local Loader = GMLK.New("Server")
Loader:LoadModules(ServerModules, { IncludeDescendants = true })

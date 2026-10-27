local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local GML = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Library"):WaitForChild("GML"))
local ServerModules = ServerStorage:WaitForChild("Modules"):WaitForChild("Client")

local Loader = GML.New("Server")
Loader:LoadModules(ServerModules, { IncludeDescendants = true })

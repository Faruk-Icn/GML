local RunService = game:GetService("RunService")

local GML = {}
GML.__index = GML

GML.Number = require(script.Number)
GML.Time = require(script.Time)
GML.Math = require(script.Math)
GML.Table = require(script.Table)
GML.Signal = require(script.Signal)

export type LoaderOptions = { IncludeDescendants: boolean?, Debug: boolean? }
export type ModuleRecord = { Identifier: string, Name: string, Priority: number, Value: any }

local function FormatTime(Duration: number): string
	return if Duration < 1 then string.format("%.2fms", Duration * 1000) else string.format("%.2fs", Duration)
end

local function GetModuleScript(Item: Instance): ModuleScript?
	if Item:IsA("ModuleScript") then
		return Item
	end
	if Item:IsA("ObjectValue") and Item.Value and Item.Value:IsA("ModuleScript") then
		return Item.Value
	end
	return nil
end

function GML.New(LoaderName: string?)
	local Self = setmetatable({}, GML)
	Self.LoaderName = LoaderName or "GML"
	Self.LoadedModules = {}
	Self.LoadOrder = {}
	Self.Errors = {}
	Self.IsLoaded = false
	Self.IsLoading = false
	return Self
end

function GML:RunLifecycle(Record: ModuleRecord, LifecycleName: string, Debug: boolean): boolean
	if type(Record.Value) ~= "table" then
		return true
	end
	local Callback = Record.Value[LifecycleName]
	if type(Callback) ~= "function" then
		return true
	end
	local Started = os.clock()
	local Success, Result = pcall(Callback, Record.Value)
	if not Success then
		local Message = LifecycleName .. " failed for " .. Record.Identifier .. ": " .. tostring(Result)
		table.insert(self.Errors, Message)
		warn("[" .. self.LoaderName .. "] " .. Message)
	elseif Debug and RunService:IsStudio() then
		print("[" .. self.LoaderName .. "] " .. LifecycleName .. " " .. Record.Identifier .. " in " .. FormatTime(os.clock() - Started))
	end
	return Success
end

function GML:LoadModules(Parent: Instance | { Instance }, Options: LoaderOptions?)
	assert(not self.IsLoading, "GML is already loading modules")
	Options = Options or {}
	local Debug = Options.Debug == true
	local Items: { Instance }
	if typeof(Parent) == "Instance" then
		Items = if Options.IncludeDescendants then Parent:GetDescendants() else Parent:GetChildren()
	else
		Items = Parent
	end
	self.IsLoading = true
	local Started = os.clock()
	local Pending: { ModuleRecord } = {}
	for _, Item in ipairs(Items) do
		local Module = GetModuleScript(Item)
		if Module and Module ~= script then
			local Identifier = Module:GetFullName()
			if not self.LoadedModules[Identifier] then
				local RequireStarted = os.clock()
				local Success, Value = pcall(require, Module)
				if Success then
					local Priority = if type(Value) == "table" then tonumber(Value.Priority) else nil
					local Record: ModuleRecord = {
						Identifier = Identifier,
						Name = Module.Name,
						Priority = Priority or 100,
						Value = Value,
					}
					self.LoadedModules[Identifier] = Record
					table.insert(Pending, Record)
					if Debug and RunService:IsStudio() then
						print("[" .. self.LoaderName .. "] Loaded " .. Identifier .. " in " .. FormatTime(os.clock() - RequireStarted))
					end
				else
					local Message = "Failed to require " .. Identifier .. ": " .. tostring(Value)
					table.insert(self.Errors, Message)
					warn("[" .. self.LoaderName .. "] " .. Message)
				end
			end
		end
	end
	table.sort(Pending, function(Left: ModuleRecord, Right: ModuleRecord)
		return if Left.Priority == Right.Priority then Left.Identifier < Right.Identifier else Left.Priority < Right.Priority
	end)
	for _, Record in ipairs(Pending) do
		table.insert(self.LoadOrder, Record)
	end
	for _, Record in ipairs(Pending) do
		self:RunLifecycle(Record, "Init", Debug)
	end
	for _, Record in ipairs(Pending) do
		self:RunLifecycle(Record, "Start", Debug)
	end
	self.IsLoading = false
	self.IsLoaded = true
	if Debug and RunService:IsStudio() then
		print("[" .. self.LoaderName .. "] Finished " .. #Pending .. " modules in " .. FormatTime(os.clock() - Started))
	end
	return self.LoadedModules
end

function GML:GetModule(Identifier: string): any
	local Record = self.LoadedModules[Identifier]
	return if Record then Record.Value else nil
end

function GML:GetModuleByName(ModuleName: string): any
	for _, Record in ipairs(self.LoadOrder) do
		if Record.Name == ModuleName then
			return Record.Value
		end
	end
	return nil
end

return GML

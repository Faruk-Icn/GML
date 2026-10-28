local Signal = require(script.Parent.Signal)

local StateMachine = {}
StateMachine.__index = StateMachine

function StateMachine.New(InitialState: string, Transitions: { [string]: { string } })
	assert(type(InitialState) == "string", "InitialState must be a string")
	assert(type(Transitions) == "table", "Transitions must be a table")
	return setmetatable({
		State = InitialState,
		Transitions = Transitions,
		Changed = Signal.New(),
		Destroyed = false,
	}, StateMachine)
end

function StateMachine:CanTransition(NextState: string): boolean
	if self.Destroyed or self.State == NextState then
		return false
	end
	for _, Allowed in ipairs(self.Transitions[self.State] or {}) do
		if Allowed == NextState then
			return true
		end
	end
	return false
end

function StateMachine:Transition(NextState: string): boolean
	if not self:CanTransition(NextState) then
		return false
	end
	local Previous = self.State
	self.State = NextState
	self.Changed:Fire(NextState, Previous)
	return true
end

function StateMachine:Destroy()
	if self.Destroyed then
		return
	end
	self.Destroyed = true
	self.Changed:Destroy()
end

return StateMachine

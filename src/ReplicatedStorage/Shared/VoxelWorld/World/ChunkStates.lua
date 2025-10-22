--[[
	ChunkStates.lua
	Chunk state machine definitions and validation

	State Flow:
	NEW -> GENERATING -> GENERATED -> MESHING -> READY
	                                             ↓  ↑
	                                          DIRTY (remesh needed)
	ANY -> UNLOADING
]]

local ChunkStates = {}

-- State definitions
ChunkStates.States = {
	NEW = "NEW",                   -- Just created, needs generation
	GENERATING = "GENERATING",     -- Terrain generation in progress
	GENERATED = "GENERATED",       -- Terrain done, needs mesh
	MESHING = "MESHING",           -- Building mesh
	READY = "READY",               -- Fully ready to render
	UNLOADING = "UNLOADING",       -- Being removed
}

-- Valid state transitions
ChunkStates.ValidTransitions = {
	[ChunkStates.States.NEW] = {
		[ChunkStates.States.GENERATING] = true,
		[ChunkStates.States.UNLOADING] = true,
	},
	[ChunkStates.States.GENERATING] = {
		[ChunkStates.States.GENERATED] = true,
		[ChunkStates.States.UNLOADING] = true,
	},
	[ChunkStates.States.GENERATED] = {
		[ChunkStates.States.MESHING] = true,
		[ChunkStates.States.UNLOADING] = true,
	},
	[ChunkStates.States.MESHING] = {
		[ChunkStates.States.READY] = true,
		[ChunkStates.States.GENERATED] = true, -- Can go back if mesh fails
		[ChunkStates.States.UNLOADING] = true,
	},
	[ChunkStates.States.READY] = {
		[ChunkStates.States.MESHING] = true, -- Remesh when dirty
		[ChunkStates.States.UNLOADING] = true,
	},
	[ChunkStates.States.UNLOADING] = {
		-- Terminal state, no transitions out
	},
}

--[[
	Check if a state transition is valid
	@param fromState string
	@param toState string
	@return boolean
]]
function ChunkStates.IsValidTransition(fromState: string, toState: string): boolean
	if not ChunkStates.ValidTransitions[fromState] then
		return false
	end
	return ChunkStates.ValidTransitions[fromState][toState] == true
end

--[[
	Get human-readable description of a state
	@param state string
	@return string
]]
function ChunkStates.GetDescription(state: string): string
	local descriptions = {
		[ChunkStates.States.NEW] = "Newly created, awaiting generation",
		[ChunkStates.States.GENERATING] = "Generating terrain",
		[ChunkStates.States.GENERATED] = "Terrain generated, awaiting mesh",
		[ChunkStates.States.MESHING] = "Building mesh",
		[ChunkStates.States.READY] = "Ready to render",
		[ChunkStates.States.UNLOADING] = "Being unloaded",
	}
	return descriptions[state] or "Unknown state"
end

--[[
	Check if chunk can be rendered
	@param state string
	@return boolean
]]
function ChunkStates.CanRender(state: string): boolean
	return state == ChunkStates.States.READY
end

--[[
	Check if chunk needs generation
	@param state string
	@return boolean
]]
function ChunkStates.NeedsGeneration(state: string): boolean
	return state == ChunkStates.States.NEW or state == ChunkStates.States.GENERATING
end

--[[
	Check if chunk needs meshing
	@param state string
	@return boolean
]]
function ChunkStates.NeedsMeshing(state: string): boolean
	return state == ChunkStates.States.GENERATED or state == ChunkStates.States.MESHING
end

return ChunkStates


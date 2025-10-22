--[[
	BlockBreakTracker.lua
	Tracks block breaking progress for multiple players mining blocks
	Handles multi-hit mining like Minecraft
]]

local BlockBreakTracker = {}
BlockBreakTracker.__index = BlockBreakTracker

function BlockBreakTracker.new()
	local self = setmetatable({
		-- Map of "x,y,z" -> { player: Player, progress: number, startTime: number, lastHit: number }
		breakingBlocks = {},
		-- Break timeout in seconds (if no hit for this long, reset progress)
		breakTimeout = 1.0,
	}, BlockBreakTracker)

	return self
end

--[[
	Get block key from coordinates
]]
local function getBlockKey(x: number, y: number, z: number): string
	return string.format("%d,%d,%d", x, y, z)
end

--[[
	Start or continue breaking a block
	@param player: Player breaking the block
	@param x, y, z: Block coordinates
	@param breakTime: Total time needed to break (seconds)
	@param dt: Time since last hit (seconds)
	@return: progress (0-1), isBroken (boolean)
]]
function BlockBreakTracker:Hit(player: Player, x: number, y: number, z: number, breakTime: number, dt: number): (number, boolean)
	local key = getBlockKey(x, y, z)
	local now = os.clock()

	local entry = self.breakingBlocks[key]

	-- Check if this is a new break or continued break
	if not entry or entry.player ~= player then
		-- New player breaking this block, reset progress
		entry = {
			player = player,
			progress = 0,
			startTime = now,
			lastHit = now,
			breakTime = breakTime
		}
		self.breakingBlocks[key] = entry
	else
		-- Check if timed out (stopped hitting for too long)
		if (now - entry.lastHit) > self.breakTimeout then
			-- Reset progress
			entry.progress = 0
			entry.startTime = now
		end

		entry.lastHit = now
	end

	-- Instant break blocks
	if breakTime <= 0 then
		self.breakingBlocks[key] = nil
		return 1.0, true
	end

	-- Unbreakable blocks
	if breakTime == math.huge then
		self.breakingBlocks[key] = nil
		return 0, false
	end

	-- Accumulate progress
	entry.progress = entry.progress + (dt / breakTime)
	entry.breakTime = breakTime  -- Update in case tool changed

	-- Check if broken
	if entry.progress >= 1.0 then
		self.breakingBlocks[key] = nil
		return 1.0, true
	end

	return entry.progress, false
end

--[[
	Get current break progress for a block
	@return: progress (0-1), player or nil
]]
function BlockBreakTracker:GetProgress(x: number, y: number, z: number): (number, Player?)
	local key = getBlockKey(x, y, z)
	local entry = self.breakingBlocks[key]

	if not entry then
		return 0, nil
	end

	-- Check timeout
	local now = os.clock()
	if (now - entry.lastHit) > self.breakTimeout then
		self.breakingBlocks[key] = nil
		return 0, nil
	end

	return entry.progress, entry.player
end

--[[
	Cancel breaking for a specific block
]]
function BlockBreakTracker:Cancel(x: number, y: number, z: number)
	local key = getBlockKey(x, y, z)
	self.breakingBlocks[key] = nil
end

--[[
	Cancel all breaking progress for a player (e.g., on disconnect)
]]
function BlockBreakTracker:CancelPlayer(player: Player)
	for key, entry in pairs(self.breakingBlocks) do
		if entry.player == player then
			self.breakingBlocks[key] = nil
		end
	end
end

--[[
	Clean up stale entries (call periodically)
]]
function BlockBreakTracker:CleanupStale()
	local now = os.clock()
	for key, entry in pairs(self.breakingBlocks) do
		if (now - entry.lastHit) > self.breakTimeout then
			self.breakingBlocks[key] = nil
		end
	end
end

--[[
	Get all blocks currently being broken (for replication)
	@return: Array of {x, y, z, progress, playerUserId}
]]
function BlockBreakTracker:GetAllBreaking(): {any}
	local result = {}
	local now = os.clock()

	for key, entry in pairs(self.breakingBlocks) do
		-- Skip stale entries
		if (now - entry.lastHit) <= self.breakTimeout then
			local x, y, z = string.match(key, "(-?%d+),(-?%d+),(-?%d+)")
			table.insert(result, {
				x = tonumber(x),
				y = tonumber(y),
				z = tonumber(z),
				progress = entry.progress,
				playerUserId = entry.player.UserId
			})
		end
	end

	return result
end

return BlockBreakTracker


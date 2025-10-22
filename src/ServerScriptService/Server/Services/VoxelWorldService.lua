--[[
	VoxelWorldService.lua
	Server-side voxel world management service
	Simplified for single player-owned world per server instance
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Core voxel modules
local VoxelWorld = require(ReplicatedStorage.Shared.VoxelWorld)
local EventManager = require(ReplicatedStorage.Shared.EventManager)
local Constants = require(ReplicatedStorage.Shared.VoxelWorld.Core.Constants)
local Config = require(ReplicatedStorage.Shared.VoxelWorld.Core.Config)
local ChunkCompressor = require(ReplicatedStorage.Shared.VoxelWorld.Memory.ChunkCompressor)
local BlockProperties = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockProperties)
local BlockBreakTracker = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockBreakTracker)
local BlockPlacementRules = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockPlacementRules)

local VoxelWorldService = {
	Name = "VoxelWorldService"
}

-- Initialize service
function VoxelWorldService:Init()
	-- Single world instance for this server
	self.world = nil
	self.worldManager = nil
	self.renderDistance = 6

	-- Player tracking
	self.players = {} -- Map of Player -> {position, chunks, tool}
	self.chunkViewers = {} -- Map of chunkKey -> set of players viewing it
	self.chunkLastAccess = {} -- Map of chunkKey -> last access os.clock()

	-- Block breaking tracker
	self.blockBreakTracker = BlockBreakTracker.new()

	-- Per-player rate limits
	self.rateLimits = {} -- Player -> {chunkWindowStart, chunksSent, modWindowStart, mods, lastPunch}

	-- Statistics
	self.stats = {
		chunksLoaded = 0,
		chunksStreamed = 0,
		chunksUnloaded = 0,
		blockChanges = 0,
		lastStreamTimeMs = 0
	}

	-- Chunk modifications tracking (for saving)
	self.modifiedChunks = {} -- Set of chunk keys that need saving

	print("VoxelWorldService: Initialized (single player-owned world)")
end

-- Check if world is ready for players to spawn
function VoxelWorldService:IsWorldReady()
	-- World must exist
	if not self.world then return false end

	-- WorldManager must exist
	if not self.worldManager then return false end

	-- Generator must exist (needed for spawn position)
	if not self.worldManager.generator then return false end

	-- Generator must have GetSpawnPosition method
	if not self.worldManager.generator.GetSpawnPosition then return false end

	return true
end

-- Initialize world with seed and render distance
function VoxelWorldService:InitializeWorld(seed, renderDistance)
	self.renderDistance = renderDistance or 6

	-- Create world instance
	local worldSeed = seed or 12345
	self.world = VoxelWorld.CreateWorld(worldSeed, self.renderDistance)
	self.worldManager = self.world:GetWorldManager()

	print(string.format("VoxelWorldService: World initialized (seed: %d, render distance: %d)",
		worldSeed, self.renderDistance))
end

-- Initialize starter chest for Skyblock (called after world generation)
function VoxelWorldService:InitializeStarterChest()
	-- Skyblock starter chest is at world coordinates (7, 66, 4)
	-- Center is (7, 65, 7), chest is 3 blocks north on the grass surface + 1
	local chestX = 7
	local chestY = 66  -- One block above grass surface (Y=65)
	local chestZ = 4   -- 3 blocks north of center

	-- Check if ChestStorageService is available
	if self.Deps and self.Deps.ChestStorageService then
		self.Deps.ChestStorageService:InitializeStarterChest(chestX, chestY, chestZ)
		print(string.format("VoxelWorldService: Initialized starter chest at (%d, %d, %d)", chestX, chestY, chestZ))
	else
		warn("VoxelWorldService: ChestStorageService not available, cannot initialize starter chest")
	end
end

-- Update world seed (called when owner joins)
function VoxelWorldService:UpdateWorldSeed(seed)
	if not seed then return end

	-- Destroy old world if it exists
	if self.world and self.world.Destroy then
		self.world:Destroy()
	end

	-- Recreate world with new seed
	self.world = VoxelWorld.CreateWorld(seed, self.renderDistance)
	self.worldManager = self.world:GetWorldManager()

	print(string.format("VoxelWorldService: World recreated with owner's seed: %d", seed))
end

-- Stream chunk to player
function VoxelWorldService:StreamChunkToPlayer(player, chunkX, chunkZ)
	local playerData = self.players[player]
	if not playerData then return false end

	local key = string.format("%d,%d", chunkX, chunkZ)

	-- Get or create chunk
	local chunk = self.worldManager:GetChunk(chunkX, chunkZ)
	if not chunk then return false end

	-- Serialize and send via EventManager
	local startTime = os.clock()
    local linear = chunk:SerializeLinear()
    local compressed = ChunkCompressor.CompressForNetwork(linear)
    compressed.x = linear.x
    compressed.z = linear.z
    compressed.state = linear.state
	local compressionTime = (os.clock() - startTime) * 1000

	EventManager:FireEvent("ChunkDataStreamed", player, {
		chunk = compressed,
		key = key
	})

	-- Update stats
	self.stats.chunksStreamed += 1
	self.stats.lastStreamTimeMs = compressionTime

	-- Track viewing reference
	self:_addViewer(player, key)
	self.chunkLastAccess[key] = os.clock()

	-- Enforce per-player chunk cap
	local perPlayerCap = (Config.PERFORMANCE and Config.PERFORMANCE.MAX_CHUNKS_PER_PLAYER) or 200
	if perPlayerCap > 0 then
		local state = self.players[player]
		if state and state.chunks then
			local centerChunkX = math.floor(state.position.X / (Constants.CHUNK_SIZE_X * Constants.BLOCK_SIZE))
			local centerChunkZ = math.floor(state.position.Z / (Constants.CHUNK_SIZE_Z * Constants.BLOCK_SIZE))
			local safeRadius = (self.renderDistance or 6) + 1
			local candidates = {}

			for k in pairs(state.chunks) do
				local cx, cz = string.match(k, "(-?%d+),(-?%d+)")
				cx, cz = tonumber(cx) or 0, tonumber(cz) or 0
				local dx = cx - centerChunkX
				local dz = cz - centerChunkZ
				local dist2 = dx*dx + dz*dz

				if dist2 > (safeRadius * safeRadius) then
					candidates[#candidates + 1] = {
						key = k,
						last = self.chunkLastAccess[k] or 0,
						dist2 = dist2
					}
				end
			end

			table.sort(candidates, function(a, b)
				if a.dist2 == b.dist2 then
					return a.last < b.last
				end
				return a.dist2 > b.dist2
			end)

			local currentCount = 0
			for _ in pairs(state.chunks) do currentCount += 1 end
			local over = (currentCount + 1) - perPlayerCap
			local i = 1

			while over > 0 and i <= #candidates do
				local victim = candidates[i].key
				if victim ~= key then
					EventManager:FireEvent("ChunkUnload", player, { key = victim })
					state.chunks[victim] = nil
					self:_removeViewer(player, victim)
					over -= 1
				end
				i += 1
			end
		end
	end

	return true
end

-- Stream needed chunks for a player
function VoxelWorldService:StreamChunksToPlayer(player, playerState)
	local state = playerState or self.players[player]
	if not state then return end

	local now = os.clock()
	local rl = self.rateLimits[player]
	if not rl or (now - rl.chunkWindowStart) >= 1 then
		rl = {chunkWindowStart = now, chunksSent = 0, modWindowStart = now, mods = 0}
		self.rateLimits[player] = rl
	end

	local remaining = math.max(0, (Config.NETWORK.MAX_CHUNKS_PER_UPDATE or 5) - rl.chunksSent)
	if remaining <= 0 then return end

	local centerChunkX = math.floor(state.position.X / (Constants.CHUNK_SIZE_X * Constants.BLOCK_SIZE))
	local centerChunkZ = math.floor(state.position.Z / (Constants.CHUNK_SIZE_Z * Constants.BLOCK_SIZE))
	local renderDistance = self.renderDistance or 6

	-- Build candidate list with forward bias
	local maxDist = renderDistance * renderDistance
	local candidates = {}
	local forward = state.moveDir or Vector3.new()
	local hasForward = (forward.Magnitude and forward.Magnitude > 0.5)
	local bias = renderDistance * 0.75

	for ox = -renderDistance, renderDistance do
		for oz = -renderDistance, renderDistance do
			local dist2 = ox*ox + oz*oz
			if dist2 <= maxDist then
				local cx = centerChunkX + ox
				local cz = centerChunkZ + oz
				local key = string.format("%d,%d", cx, cz)

				if not state.chunks[key] then
					local score = dist2
					if hasForward then
						local len = math.sqrt(ox*ox + oz*oz)
						if len > 1e-3 then
							local ndx, ndz = ox/len, oz/len
							local dot = ndx * forward.X + ndz * forward.Z
							if dot then
								dot = math.clamp(dot, -1, 1)
								score = score - (dot * bias)
							end
						end
					end
					table.insert(candidates, { cx = cx, cz = cz, key = key, score = score })
				end
			end
		end
	end

	table.sort(candidates, function(a, b)
		return a.score < b.score
	end)

	local sent = 0
	for i = 1, #candidates do
		local cand = candidates[i]
		local ok = self:StreamChunkToPlayer(player, cand.cx, cand.cz)
		if ok then
			state.chunks[cand.key] = true
			rl.chunksSent += 1
			sent += 1
			if sent >= remaining then
				break
			end
		end
	end
end

-- Stream chunks for all players
function VoxelWorldService:StreamChunksToPlayers()
	-- Safety check: Don't stream if world isn't initialized yet
	if not self.world or not self.worldManager then
		return
	end

	for player, state in pairs(self.players) do
		self:StreamChunksToPlayer(player, state)

		-- Unload far chunks
		local centerChunkX = math.floor(state.position.X / (Constants.CHUNK_SIZE_X * Constants.BLOCK_SIZE))
		local centerChunkZ = math.floor(state.position.Z / (Constants.CHUNK_SIZE_Z * Constants.BLOCK_SIZE))
		local extra = (Config.NETWORK and Config.NETWORK.UNLOAD_EXTRA_RADIUS) or 0
		local renderDist = self.renderDistance or 6
		local maxDist = (renderDist + 2 + extra)

		for key in pairs(state.chunks) do
			local cx, cz = string.match(key, "(-?%d+),(-?%d+)")
			cx, cz = tonumber(cx) or 0, tonumber(cz) or 0
			local dx = cx - centerChunkX
			local dz = cz - centerChunkZ

			if (dx * dx + dz * dz) > (maxDist * maxDist) then
				EventManager:FireEvent("ChunkUnload", player, { key = key })
				state.chunks[key] = nil
				self.stats.chunksUnloaded += 1
				self:_removeViewer(player, key)
			end
		end
	end
end

-- Set block in world
function VoxelWorldService:SetBlock(x, y, z, blockId, player, metadata)
	if not self.worldManager then return false end

	-- Set block
	local success = self.worldManager:SetBlock(x, y, z, blockId)
	if not success then return false end

	-- Set metadata if provided
	if metadata and metadata ~= 0 then
		self.worldManager:SetBlockMetadata(x, y, z, metadata)
	end

	-- After changing a block, update nearby stair shapes
	self:_updateNeighborStairShapes(x, y, z)

	-- Mark chunk as modified
	local chunkX = math.floor(x / Constants.CHUNK_SIZE_X)
	local chunkZ = math.floor(z / Constants.CHUNK_SIZE_Z)
	local key = string.format("%d,%d", chunkX, chunkZ)
	self.modifiedChunks[key] = true
	print(string.format("🔄 Marked chunk (%d,%d) as modified (block %d at %d,%d,%d, meta:%d)", chunkX, chunkZ, blockId, x, y, z, metadata or 0))

	-- Notify all players
	for otherPlayer, otherData in pairs(self.players) do
		local distance = math.sqrt(
			(x * Constants.BLOCK_SIZE - otherData.position.X)^2 +
			(z * Constants.BLOCK_SIZE - otherData.position.Z)^2
		)

		if distance <= (Config.NETWORK.BLOCK_UPDATE_DISTANCE or 500) then
			EventManager:FireEvent("BlockChanged", otherPlayer, {
				x = x,
				y = y,
				z = z,
				blockId = blockId,
				metadata = metadata or 0,  -- NEW: Include metadata in network sync
				player = player and player.UserId or nil
			})
		end
	end

	self.stats.blockChanges += 1
	return true
end

-- Reject block change
function VoxelWorldService:RejectBlockChange(player, data, reason)
	EventManager:FireEvent("BlockChangeRejected", player, {
		x = data.x,
		y = data.y,
		z = data.z,
		reason = reason
	})
end

-- Handle player punch (block breaking)
function VoxelWorldService:HandlePlayerPunch(player, punchData)
	if not punchData or not punchData.x or not punchData.y or not punchData.z then
		warn("Invalid punch data from", player.Name)
		return
	end

	local x, y, z = punchData.x, punchData.y, punchData.z
	local playerData = self.players[player]
	if not playerData then return end

	-- Rate limiting
	local now = os.clock()
	local rl = self.rateLimits[player]
	if rl and rl.lastPunch and (now - rl.lastPunch) < 0.1 then
		return
	end

	if not rl then
		rl = {chunkWindowStart = now, chunksSent = 0, modWindowStart = now, mods = 0, lastPunch = now}
		self.rateLimits[player] = rl
	end
	rl.lastPunch = now

	-- Validate distance
	local character = player.Character
	if not character then return end

	local head = character:FindFirstChild("Head")
	if not head then return end

	local blockCenter = Vector3.new(
		x * Constants.BLOCK_SIZE + Constants.BLOCK_SIZE * 0.5,
		y * Constants.BLOCK_SIZE + Constants.BLOCK_SIZE * 0.5,
		z * Constants.BLOCK_SIZE + Constants.BLOCK_SIZE * 0.5
	)

	local distance3D = (blockCenter - head.Position).Magnitude
	local maxReach = 4.5 * Constants.BLOCK_SIZE + 2

	if distance3D > maxReach then
		self:RejectBlockChange(player, {x = x, y = y, z = z}, "too_far")
		return
	end

	-- Get block
	local blockId = self.worldManager:GetBlock(x, y, z)
	if not blockId or blockId == Constants.BlockType.AIR then
		return
	end

	-- Check if breakable
	if not BlockProperties:IsBreakable(blockId) then
		self:RejectBlockChange(player, {x = x, y = y, z = z}, "unbreakable")
		return
	end

	-- Get tool info
	local toolType = (playerData.tool and playerData.tool.type) or BlockProperties.ToolType.NONE
	local toolTier = (playerData.tool and playerData.tool.tier) or BlockProperties.ToolTier.NONE

	-- Calculate break time
	local breakTime, canBreak = BlockProperties:GetBreakTime(blockId, toolType, toolTier)
	if not canBreak then
		self:RejectBlockChange(player, {x = x, y = y, z = z}, "wrong_tool")
		return
	end

	-- Track breaking progress
	local dt = punchData.dt or 0.25
	local progress, isBroken = self.blockBreakTracker:Hit(player, x, y, z, breakTime, dt)

	-- Broadcast punch animation
	pcall(function()
		EventManager:FireEventToAll("PlayerPunched", {
			userId = player.UserId,
			x = x, y = y, z = z,
			progress = progress,
			timeMs = math.floor(os.clock() * 1000)
		})
	end)

	if isBroken then
		print(string.format("Player %s broke block at (%d, %d, %d) - blockId: %d",
			player.Name, x, y, z, blockId))

		local canHarvest = BlockProperties:CanHarvest(blockId, toolType, toolTier)

		-- Handle special block types (e.g., chests)
		if blockId == Constants.BlockType.CHEST then
			-- Remove chest data and close for viewers
			if self.Deps and self.Deps.ChestStorageService then
				self.Deps.ChestStorageService:RemoveChest(x, y, z)
			end
		end

		-- Remove block FIRST so it disappears before item spawns
		self:SetBlock(x, y, z, Constants.BlockType.AIR, player)

		-- Fire break event after block is removed
		EventManager:FireEventToAll("BlockBroken", {
			x = x, y = y, z = z,
			blockId = blockId,
			playerUserId = player.UserId,
			canHarvest = canHarvest
		})

		-- Spawn dropped item if player can harvest the block
		if canHarvest and self.Deps and self.Deps.DroppedItemService then
			-- Check if this full block should drop as 2 slabs instead
			local dropItemId = blockId
			local dropCount = 1

			if Constants.ShouldDropAsSlabs(blockId) then
				-- This full block (e.g., Oak Planks) should drop as 2 slabs (e.g., Oak Slabs)
				dropItemId = Constants.GetSlabFromFullBlock(blockId)
				dropCount = 2
				print(string.format("📦 Block %d drops as 2x slab %d", blockId, dropItemId))
			end

			-- Minimal velocity - just let it drop naturally
			local popVelocity = Vector3.new(
				math.random(-1, 1) * 0.5,
				0, -- No upward velocity - spawn and drop
				math.random(-1, 1) * 0.5
			)
			self.Deps.DroppedItemService:SpawnItem(
				dropItemId,
				dropCount,
				Vector3.new(x, y, z),
				popVelocity,
				true -- Is block coordinates
			)
		end
	else
		EventManager:FireEventToAll("BlockBreakProgress", {
			x = x, y = y, z = z,
			progress = progress,
			playerUserId = player.UserId
		})
	end
end

-- Handle block placement
function VoxelWorldService:RequestBlockPlace(player, placeData)
	if not placeData or not placeData.x or not placeData.y or not placeData.z or not placeData.blockId then
		warn("Invalid block place data from", player.Name)
		return
	end

	local x, y, z, blockId = placeData.x, placeData.y, placeData.z, placeData.blockId
	local playerData = self.players[player]
	if not playerData then return end

	-- Debug: Log placement request
	print(string.format("[BlockPlace] %s requesting placement at (%d,%d,%d) with blockId: %d",
		player.Name, x, y, z, blockId))

	-- Rate limiting
	local now = os.clock()
	local rl = self.rateLimits[player]
	if not rl then
		rl = {chunkWindowStart = now, chunksSent = 0, modWindowStart = now, mods = 0, lastPlace = 0}
		self.rateLimits[player] = rl
	end

	if (now - (rl.lastPlace or 0)) < 0.2 then
		return
	end
	rl.lastPlace = now

	-- Validate distance and collision
	local character = player.Character
	if not character then return end

	local head = character:FindFirstChild("Head")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not head or not rootPart then return end

	-- Use head position for distance check (where player looks from)
	-- Use rootPart position for collision check (body center)
	local headPos = head.Position
	local bodyPos = rootPart.Position

	-- Check if this is a potential slab merge before validation
	-- If placing a slab where another slab exists, skip the space_occupied check
	local isPotentialSlabMerge = false
	if Constants.IsSlab(blockId) then
		local existingBlock = self.worldManager:GetBlock(x, y, z)
		if Constants.IsSlab(existingBlock) then
			isPotentialSlabMerge = true
			print(string.format("[BlockPlace] 🔍 Detected potential slab merge at (%d,%d,%d)", x, y, z))
		end
	end

	-- Standard placement validation (distance and collision)
	-- For potential slab merges, we'll validate after checking if they can actually merge
	local canPlace, reason
	if not isPotentialSlabMerge then
		canPlace, reason = BlockPlacementRules:CanPlace(
			self.worldManager,
			x, y, z,
			blockId,
			headPos,     -- Distance check uses head position
			bodyPos      -- Collision check uses body position
		)
	else
		-- For slab merges, only check distance, not space occupation
		local blockCenter = Vector3.new(
			x * Constants.BLOCK_SIZE + Constants.BLOCK_SIZE * 0.5,
			y * Constants.BLOCK_SIZE + Constants.BLOCK_SIZE * 0.5,
			z * Constants.BLOCK_SIZE + Constants.BLOCK_SIZE * 0.5
		)
		local distance = (blockCenter - headPos).Magnitude
		local maxReach = 4.5 * Constants.BLOCK_SIZE + 2
		canPlace = distance <= maxReach
		reason = canPlace and nil or "too_far"
	end

	if not canPlace then
		-- Debug logging for placement rejection
		local currentBlock = self.worldManager:GetBlock(x, y, z)
		local Constants = require(game.ReplicatedStorage.Shared.VoxelWorld.Core.Constants)
		local blockName = "unknown"
		if currentBlock == Constants.BlockType.AIR then blockName = "AIR"
		elseif currentBlock == Constants.BlockType.STONE then blockName = "STONE"
		elseif currentBlock == Constants.BlockType.DIRT then blockName = "DIRT"
		elseif currentBlock == Constants.BlockType.GRASS then blockName = "GRASS"
		elseif currentBlock == Constants.BlockType.LOG then blockName = "LOG"
		elseif currentBlock == Constants.BlockType.LEAVES then blockName = "LEAVES"
		end

		print(string.format("[BlockPlace] ❌ REJECTED for %s at (%d,%d,%d)", player.Name, x, y, z))
		print(string.format("  Current block: %d (%s)", currentBlock or -1, blockName))
		print(string.format("  Reason: %s", reason or "unknown"))
		print(string.format("  Trying to place: blockId %d", blockId))

		self:RejectBlockChange(player, {x = x, y = y, z = z}, reason or "cannot_place")
		return
	end

	-- Debug: Successful placement check
	print(string.format("[BlockPlace] ✅ Validation passed for %s at (%d,%d,%d)", player.Name, x, y, z))

	-- Debug: Log placement request details
	local targetBlock = self.worldManager:GetBlock(placeData.targetBlockPos.X, placeData.targetBlockPos.Y, placeData.targetBlockPos.Z)
	local targetMetadata = self.worldManager:GetBlockMetadata(placeData.targetBlockPos.X, placeData.targetBlockPos.Y, placeData.targetBlockPos.Z)
	local targetOrientation = Constants.IsSlab(targetBlock) and Constants.GetVerticalOrientation(targetMetadata) or -1

	print(string.format("[BlockPlace] 📍 Placement request: pos=(%d,%d,%d), blockId=%d", x, y, z, blockId))
	print(string.format("[BlockPlace] 📍 Target block: pos=(%d,%d,%d), id=%d, metadata=%d, orientation=%s",
		placeData.targetBlockPos.X, placeData.targetBlockPos.Y, placeData.targetBlockPos.Z,
		targetBlock, targetMetadata,
		targetOrientation == Constants.BlockMetadata.VERTICAL_TOP and "TOP" or
		targetOrientation == Constants.BlockMetadata.VERTICAL_BOTTOM and "BOTTOM" or "N/A"))
	print(string.format("[BlockPlace] 📍 Face clicked: normal=(%.1f,%.1f,%.1f), hitPos=(%.2f,%.2f,%.2f)",
		placeData.faceNormal.X, placeData.faceNormal.Y, placeData.faceNormal.Z,
		placeData.hitPosition.X, placeData.hitPosition.Y, placeData.hitPosition.Z))

	-- Calculate rotation and vertical orientation for rotatable blocks
	local metadata = 0
	local BlockRegistry = require(game.ReplicatedStorage.Shared.VoxelWorld.World.BlockRegistry)
	local BlockRotation = require(game.ReplicatedStorage.Shared.VoxelWorld.World.BlockRotation)
	local blockInfo = BlockRegistry:GetBlock(blockId)

	if blockInfo and (blockInfo.hasRotation or blockInfo.stairShape or blockInfo.slabShape) then
		-- Get player's facing direction for horizontal rotation (Minecraft parity)
		local lookVector = rootPart.CFrame.LookVector
		local rotation = BlockRotation.GetRotationFromLookVector(lookVector)
		-- In Minecraft, stair yaw is derived from player facing, not clicked face
		metadata = Constants.SetRotation(metadata, rotation)

		-- Calculate vertical orientation (upside-down for stairs, top/bottom for slabs)
		-- Minecraft-style: determines based on which part of the block face was clicked
		local hitPosition = placeData.hitPosition
		local faceNormal = placeData.faceNormal
		local targetBlockPos = placeData.targetBlockPos

		if hitPosition and faceNormal and targetBlockPos then
			local verticalOrientation = Constants.BlockMetadata.VERTICAL_BOTTOM

			-- Calculate relative position within the targeted block face
			-- The hit position is in world coordinates
			local blockWorldPos = Vector3.new(
				targetBlockPos.X * Constants.BLOCK_SIZE,
				targetBlockPos.Y * Constants.BLOCK_SIZE,
				targetBlockPos.Z * Constants.BLOCK_SIZE
			)

			-- Calculate position within the block (0 to BLOCK_SIZE range)
			local relativePos = hitPosition - blockWorldPos

			-- Determine orientation based on face clicked and position (Minecraft logic)
			-- This determines the orientation of the NEW block being placed
			if faceNormal.Y == 1 then
				-- Clicked top face → place bottom slab/stair (sitting on top)
				verticalOrientation = Constants.BlockMetadata.VERTICAL_BOTTOM
			elseif faceNormal.Y == -1 then
				-- Clicked bottom face → place top slab/stair (hanging from bottom)
				verticalOrientation = Constants.BlockMetadata.VERTICAL_TOP
			else
				-- Clicked side face → decide top/bottom by Y within FULL block space (Minecraft behavior)
				-- Normalize using full block height to avoid edge rounding on half blocks
				local normalizedY = math.clamp((relativePos.Y / Constants.BLOCK_SIZE), 0, 1)
				local EPS = 1e-3
				if normalizedY > (0.5 + EPS) then
					verticalOrientation = Constants.BlockMetadata.VERTICAL_TOP
				elseif normalizedY < (0.5 - EPS) then
					verticalOrientation = Constants.BlockMetadata.VERTICAL_BOTTOM
				else
					-- Tie-break near midline: favor bottom (matches user expectation on boundary)
					verticalOrientation = Constants.BlockMetadata.VERTICAL_BOTTOM
				end
				print(string.format("[BlockPlace] 🔍 Side click: normalizedY=%.3f → %s",
					normalizedY,
					(verticalOrientation == Constants.BlockMetadata.VERTICAL_TOP) and "TOP" or "BOTTOM"))
			end

			metadata = Constants.SetVerticalOrientation(metadata, verticalOrientation)

			-- Compute and persist stair shape (Minecraft parity) on placement
			if blockInfo and blockInfo.stairShape then
				local ROT_N, ROT_E, ROT_S, ROT_W = Constants.BlockMetadata.ROTATION_NORTH, Constants.BlockMetadata.ROTATION_EAST, Constants.BlockMetadata.ROTATION_SOUTH, Constants.BlockMetadata.ROTATION_WEST
				local function rotLeft(r) return (r + 3) % 4 end
				local function rotRight(r) return (r + 1) % 4 end
				local function rotOpp(r) return (r + 2) % 4 end
				local function dirFromRot(r)
					if r == ROT_N then return 0, 0, 1 end
					if r == ROT_E then return 1, 0, 0 end
					if r == ROT_S then return 0, 0, -1 end
					return -1, 0, 0
				end
				local function isSameHalfStair(nx, ny, nz)
					local nid = self.worldManager:GetBlock(nx, ny, nz)
					local BlockRegistry = require(game.ReplicatedStorage.Shared.VoxelWorld.World.BlockRegistry)
					local ndef = BlockRegistry:GetBlock(nid)
					if not (ndef and ndef.stairShape) then return false end
					local nmeta = self.worldManager:GetBlockMetadata(nx, ny, nz)
					local nvert = Constants.GetVerticalOrientation(nmeta)
					if nvert ~= verticalOrientation then return false end
					return true, Constants.GetRotation(nmeta), Constants.GetStairShape(nmeta)
				end
				local fx, _, fz = dirFromRot(rotation)
				local bx, bz = -fx, -fz
				local rx, _, rz = dirFromRot(rotRight(rotation))
				local lx, _, lz = dirFromRot(rotLeft(rotation))
				local function isDifferentOrientation(checkRot)
					local dx, _, dz = dirFromRot(checkRot)
					local ok, nrot, nshape = isSameHalfStair(x + dx, y, z + dz)
					if not ok then return true end
					if nrot ~= rotation then return true end
					-- Same facing neighbor blocks corner unless neighbor is STRAIGHT (vanilla guard)
					return nshape == Constants.BlockMetadata.STAIR_SHAPE_STRAIGHT
				end
				local shape = Constants.BlockMetadata.STAIR_SHAPE_STRAIGHT
				-- OUTER via front neighbor perpendicular to our facing
				local okF, frot = isSameHalfStair(x + fx, y, z + fz)
				if okF then
					if frot == rotLeft(rotation) and isDifferentOrientation(rotOpp(frot)) then
						shape = Constants.BlockMetadata.STAIR_SHAPE_OUTER_LEFT
					elseif frot == rotRight(rotation) and isDifferentOrientation(rotOpp(frot)) then
						shape = Constants.BlockMetadata.STAIR_SHAPE_OUTER_RIGHT
					end
				end
				-- INNER via back neighbor perpendicular to our facing (no additional guard per vanilla behavior)
				if shape == Constants.BlockMetadata.STAIR_SHAPE_STRAIGHT then
					local okB, brot = isSameHalfStair(x + bx, y, z + bz)
					if okB then
						if brot == rotLeft(rotation) then
							shape = Constants.BlockMetadata.STAIR_SHAPE_INNER_LEFT
						elseif brot == rotRight(rotation) then
							shape = Constants.BlockMetadata.STAIR_SHAPE_INNER_RIGHT
						end
					end
				end
				metadata = Constants.SetStairShape(metadata, shape)
			end

			-- Neighbor snapping for stairs (disabled by default; rendering will honor shape)
			if blockInfo and blockInfo.stairShape and Config and Config.PLACEMENT and Config.PLACEMENT.STAIR_AUTO_ROTATE_ON_PLACE then
				local function rotLeft(r)
					return (r + 3) % 4
				end
				local function rotRight(r)
					return (r + 1) % 4
				end
				local function dirFromRot(r)
					if r == Constants.BlockMetadata.ROTATION_NORTH then return 0, 0, 1 end
					if r == Constants.BlockMetadata.ROTATION_EAST then return 1, 0, 0 end
					if r == Constants.BlockMetadata.ROTATION_SOUTH then return 0, 0, -1 end
					return -1, 0, 0 -- WEST
				end
				local function isSameStair(nx, ny, nz)
					local nid = self.worldManager:GetBlock(nx, ny, nz)
					if nid ~= blockId then return false end
					local nmeta = self.worldManager:GetBlockMetadata(nx, ny, nz)
					local nvert = Constants.GetVerticalOrientation(nmeta)
					return nvert == verticalOrientation, Constants.GetRotation(nmeta)
				end
				local function shapeForRotation(r)
					-- Returns preferred shape string if achievable with neighbors for rotation r, or nil
					local fx, _, fz = dirFromRot(r)
					local rx, _, rz = dirFromRot(rotRight(r))
					local lx, _, lz = dirFromRot(rotLeft(r))
					-- Inner corner check (highest priority)
					local okFront, frontRot = isSameStair(x + fx, y, z + fz)
					if okFront then
						if frontRot == rotLeft(r) then return "inner_left" end
						if frontRot == rotRight(r) then return "inner_right" end
					end
					-- Outer corner check
					local okLeft, leftRot = isSameStair(x + lx, y, z + lz)
					if okLeft and leftRot == rotLeft(r) then return "outer_left" end
					local okRight, rightRot = isSameStair(x + rx, y, z + rz)
					if okRight and rightRot == rotRight(r) then return "outer_right" end
					return nil
				end

				-- Try current rotation first, then left/right to find a corner snap
				local candidates = {
					rotation,
					rotLeft(rotation),
					rotRight(rotation)
				}
				local snappedRotation = rotation
				local snappedShape = shapeForRotation(rotation)
				if not snappedShape then
					for _, cand in ipairs(candidates) do
						local shape = shapeForRotation(cand)
						if shape then
							-- Prefer inner over outer implicitly because shapeForRotation checks inner first
							snappedRotation = cand
							snappedShape = shape
							break
						end
					end
				end
				if snappedRotation ~= rotation then
					metadata = Constants.SetRotation(metadata, snappedRotation)
					rotation = snappedRotation
					print(string.format("[BlockPlace] 🎯 Stair snapped to %s via neighbor (rotation=%s)", snappedShape or "straight", BlockRotation.GetRotationName(rotation)))
				end
			end

			-- Optional placement assist: choose rotation to yield a corner when possible (outer-first parity, but prefer corner over straight)
			if blockInfo and blockInfo.stairShape and Config and Config.PLACEMENT and Config.PLACEMENT.STAIR_CORNER_ON_PLACEMENT then
				local function rotLeft(r)
					return (r + 3) % 4
				end
				local function rotRight(r)
					return (r + 1) % 4
				end
				local function dirFromRot(r)
					if r == Constants.BlockMetadata.ROTATION_NORTH then return 0, 0, 1 end
					if r == Constants.BlockMetadata.ROTATION_EAST then return 1, 0, 0 end
					if r == Constants.BlockMetadata.ROTATION_SOUTH then return 0, 0, -1 end
					return -1, 0, 0
				end
				local function getStairRot(nx, ny, nz)
					local nid = self.worldManager:GetBlock(nx, ny, nz)
					local BlockRegistry = require(game.ReplicatedStorage.Shared.VoxelWorld.World.BlockRegistry)
					local ndef = BlockRegistry:GetBlock(nid)
					if not (ndef and ndef.stairShape) then return nil end
					local nmeta = self.worldManager:GetBlockMetadata(nx, ny, nz)
					local nvert = Constants.GetVerticalOrientation(nmeta)
					if nvert ~= Constants.GetVerticalOrientation(metadata) then return nil end
					return Constants.GetRotation(nmeta)
				end
				local function shapeFor(r)
					local fx, _, fz = dirFromRot(r)
					local rx, _, rz = dirFromRot(rotRight(r))
					local lx, _, lz = dirFromRot(rotLeft(r))
					-- Outer first
					local lrot = getStairRot(x + lx, y, z + lz)
					if lrot and lrot == rotLeft(r) then return "outer_left" end
					local rrot = getStairRot(x + rx, y, z + rz)
					if rrot and rrot == rotRight(r) then return "outer_right" end
					-- Inner second (behind)
					local brot = getStairRot(x + fx, y, z + fz)
					if brot and brot == rotLeft(r) then return "inner_left" end
					if brot and brot == rotRight(r) then return "inner_right" end
					return nil
				end
				local candidates = {rotation, rotLeft(rotation), rotRight(rotation)}
				for _, cand in ipairs(candidates) do
					local s = shapeFor(cand)
					if s then
						rotation = cand
						metadata = Constants.SetRotation(metadata, rotation)
						break
					end
				end
			end

			local orientName = verticalOrientation == Constants.BlockMetadata.VERTICAL_TOP and "TOP/UPSIDE_DOWN" or "BOTTOM/NORMAL"
			print(string.format("[BlockPlace] 🔄 Block orientation: %s rotation, %s vertical (metadata: %d)",
				BlockRotation.GetRotationName(rotation), orientName, metadata))
		else
			print(string.format("[BlockPlace] 🔄 Rotatable block, rotation: %s (%d)", BlockRotation.GetRotationName(rotation), rotation))
		end
	end

	-- Minecraft-style slab merging: Check if we're placing a slab where another slab exists
	-- Special case: When clicking TOP of a bottom slab or BOTTOM of a top slab, redirect placement
	local actualX, actualY, actualZ = x, y, z
	local actualBlockId = blockId
	local actualMetadata = metadata

	print(string.format("[BlockPlace] 🔄 Checking slab merging logic for blockId=%d at (%d,%d,%d)", blockId, x, y, z))

	if Constants.IsSlab(blockId) then
		local faceNormal = placeData.faceNormal

		-- Check if we need to redirect placement for slab stacking
		if faceNormal and faceNormal.Y == 1 then
			-- Clicked top face - check if there's a slab BELOW
			local belowBlock = self.worldManager:GetBlock(x, y - 1, z)
			local belowMetadata = self.worldManager:GetBlockMetadata(x, y - 1, z)

			if Constants.IsSlab(belowBlock) then
				local belowOrientation = Constants.GetVerticalOrientation(belowMetadata)
				-- If clicking top of a bottom slab, place TOP slab at the slab's position
				if belowOrientation == Constants.BlockMetadata.VERTICAL_BOTTOM then
					actualY = y - 1
					-- Override orientation to fill the empty half (top half)
					actualMetadata = Constants.SetVerticalOrientation(metadata, Constants.BlockMetadata.VERTICAL_TOP)
					print(string.format("[BlockPlace] 📍 Redirecting to Y=%d, placing TOP slab to fill empty half", actualY))
				end
			end
		elseif faceNormal and faceNormal.Y == -1 then
			-- Clicked bottom face - check if there's a slab ABOVE
			local aboveBlock = self.worldManager:GetBlock(x, y + 1, z)
			local aboveMetadata = self.worldManager:GetBlockMetadata(x, y + 1, z)

			if Constants.IsSlab(aboveBlock) then
				local aboveOrientation = Constants.GetVerticalOrientation(aboveMetadata)
				-- If clicking bottom of a top slab, place BOTTOM slab at the slab's position
				if aboveOrientation == Constants.BlockMetadata.VERTICAL_TOP then
					actualY = y + 1
					-- Override orientation to fill the empty half (bottom half)
					actualMetadata = Constants.SetVerticalOrientation(metadata, Constants.BlockMetadata.VERTICAL_BOTTOM)
					print(string.format("[BlockPlace] 📍 Redirecting to Y=%d, placing BOTTOM slab to fill empty half", actualY))
				end
			end
		end

		-- Now check the actual target position for merging
		local existingBlock = self.worldManager:GetBlock(actualX, actualY, actualZ)
		local existingMetadata = self.worldManager:GetBlockMetadata(actualX, actualY, actualZ)

		if Constants.IsSlab(existingBlock) then
			-- Both are slabs - check if they can merge (use actualMetadata which may have been overridden)
			local canMerge, fullBlockId = Constants.CanSlabsCombine(
				existingBlock, existingMetadata,
				blockId, actualMetadata
			)

			if canMerge then
				-- Merge into full block
				actualBlockId = fullBlockId
				actualMetadata = 0  -- Full blocks don't need orientation metadata
				print(string.format("[BlockPlace] 🧱 Slab merging! Converting slabs at (%d,%d,%d) into full block %d",
					actualX, actualY, actualZ, fullBlockId))
			else
				-- Same type, same orientation - reject as occupied
				print(string.format("[BlockPlace] ❌ Cannot place slab - same orientation already exists at (%d,%d,%d)", actualX, actualY, actualZ))
				self:RejectBlockChange(player, {x = actualX, y = actualY, z = actualZ}, "space_occupied")
				return
			end
		end
	end

	-- Check inventory (consume the original slab item from player's hotbar)
	if self.Deps and self.Deps.PlayerInventoryService then
		local inventoryService = self.Deps.PlayerInventoryService
		local hotbarSlot = placeData.hotbarSlot or 1

		if not inventoryService:HasItem(player, blockId) then
			self:RejectBlockChange(player, {x = x, y = y, z = z}, "no_item")
			return
		end

		local consumed = inventoryService:ConsumeFromHotbar(player, hotbarSlot, blockId)
		if not consumed then
			self:RejectBlockChange(player, {x = x, y = y, z = z}, "consume_failed")
			return
		end
	end

	-- Place block with metadata (use actualX/Y/Z and actualBlockId/Metadata, which may be a full block if slabs merged)
    local success = self:SetBlock(actualX, actualY, actualZ, actualBlockId, player, actualMetadata)
    if success then
        -- Recompute shapes for placed stair and neighbors immediately, so player sees corner on placement
        local placedChanged = self:_recomputeStairShapeAt(actualX, actualY, actualZ)
        local neighborChanged = self:_updateNeighborStairShapes(actualX, actualY, actualZ)
		if actualBlockId ~= blockId then
			print(string.format("Player %s merged slabs into full block %d at (%d, %d, %d)",
				player.Name, actualBlockId, actualX, actualY, actualZ))
		else
			print(string.format("Player %s placed block %d at (%d, %d, %d) with metadata %d",
				player.Name, actualBlockId, actualX, actualY, actualZ, actualMetadata))
		end
	end
end

-- Recompute stair shape for a block and persist metadata (Minecraft parity)
function VoxelWorldService:_recomputeStairShapeAt(x, y, z)
	local blockId = self.worldManager:GetBlock(x, y, z)
	local BlockRegistry = require(game.ReplicatedStorage.Shared.VoxelWorld.World.BlockRegistry)
	local def = BlockRegistry:GetBlock(blockId)
	if not (def and def.stairShape) then return end
	local meta = self.worldManager:GetBlockMetadata(x, y, z)
	local rotation = Constants.GetRotation(meta)
	local verticalOrientation = Constants.GetVerticalOrientation(meta)
	local ROT_N, ROT_E, ROT_S, ROT_W = Constants.BlockMetadata.ROTATION_NORTH, Constants.BlockMetadata.ROTATION_EAST, Constants.BlockMetadata.ROTATION_SOUTH, Constants.BlockMetadata.ROTATION_WEST
	local function rotLeft(r) return (r + 3) % 4 end
	local function rotRight(r) return (r + 1) % 4 end
	local function rotOpp(r) return (r + 2) % 4 end
	local function dirFromRot(r)
		if r == ROT_N then return 0, 0, 1 end
		if r == ROT_E then return 1, 0, 0 end
		if r == ROT_S then return 0, 0, -1 end
		return -1, 0, 0
	end
	local function isSameHalfStair(nx, ny, nz)
		local nid = self.worldManager:GetBlock(nx, ny, nz)
		local ndef = BlockRegistry:GetBlock(nid)
		if not (ndef and ndef.stairShape) then return false end
		local nmeta = self.worldManager:GetBlockMetadata(nx, ny, nz)
		local nvert = Constants.GetVerticalOrientation(nmeta)
		if nvert ~= verticalOrientation then return false end
		return true, Constants.GetRotation(nmeta)
	end
	local fx, _, fz = dirFromRot(rotation)
	local bx, bz = -fx, -fz
	local rx, _, rz = dirFromRot(rotRight(rotation))
	local lx, _, lz = dirFromRot(rotLeft(rotation))
	local function isDifferentOrientation(checkRot)
		local dx, _, dz = dirFromRot(checkRot)
		local ok, nrot = isSameHalfStair(x + dx, y, z + dz)
		if not ok then return true end
		return nrot ~= rotation
	end
	local shape = Constants.BlockMetadata.STAIR_SHAPE_STRAIGHT
	local okF, frot = isSameHalfStair(x + fx, y, z + fz)
	if okF then
		if frot == rotLeft(rotation) and isDifferentOrientation(rotOpp(frot)) then
			shape = Constants.BlockMetadata.STAIR_SHAPE_OUTER_LEFT
		elseif frot == rotRight(rotation) and isDifferentOrientation(rotOpp(frot)) then
			shape = Constants.BlockMetadata.STAIR_SHAPE_OUTER_RIGHT
		end
	end
	if shape == Constants.BlockMetadata.STAIR_SHAPE_STRAIGHT then
		local okB, brot = isSameHalfStair(x + bx, y, z + bz)
		if okB then
			if brot == rotLeft(rotation) and isDifferentOrientation(brot) then
				shape = Constants.BlockMetadata.STAIR_SHAPE_INNER_LEFT
			elseif brot == rotRight(rotation) and isDifferentOrientation(brot) then
				shape = Constants.BlockMetadata.STAIR_SHAPE_INNER_RIGHT
			end
		end
	end
	local newMeta = Constants.SetStairShape(meta, shape)
    if newMeta ~= meta then
		self.worldManager:SetBlockMetadata(x, y, z, newMeta)
		local chunkX = math.floor(x / Constants.CHUNK_SIZE_X)
		local chunkZ = math.floor(z / Constants.CHUNK_SIZE_Z)
		local key = string.format("%d,%d", chunkX, chunkZ)
		self.modifiedChunks[key] = true

		-- Broadcast metadata-only change so clients remesh with new shape
		local blockId = self.worldManager:GetBlock(x, y, z)
		for otherPlayer, _ in pairs(self.players) do
			pcall(function()
				EventManager:FireEvent("BlockChanged", otherPlayer, {
					x = x,
					y = y,
					z = z,
					blockId = blockId,
					metadata = newMeta
				})
			end)
		end
        return true
    end
    return false
end

-- Call after a block changes to update nearby stair shapes
function VoxelWorldService:_updateNeighborStairShapes(x, y, z)
    local changed = {}
    for _, d in ipairs({ {1,0,0}, {-1,0,0}, {0,0,1}, {0,0,-1} }) do
        local nx, ny, nz = x + d[1], y + d[2], z + d[3]
        if self:_recomputeStairShapeAt(nx, ny, nz) then
            changed[#changed + 1] = {nx, ny, nz}
        end
    end
    return changed
end

-- Update player position
function VoxelWorldService:UpdatePlayerPosition(player, positionOrX, maybeZ)
	local character = player.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local characterPos = rootPart.Position
	local x, z = characterPos.X, characterPos.Z
	local now = os.clock()

	local state = self.players[player]
	if not state then
		self.players[player] = {
			position = Vector3.new(x, characterPos.Y, z),
			prevPosition = Vector3.new(x, characterPos.Y, z),
			moveDir = Vector3.new(),
			chunks = {},
			lastUpdate = now
		}
	else
		local prev = state.position
		state.prevPosition = prev
		state.position = Vector3.new(x, characterPos.Y, z)
		state.lastUpdate = now

		local dx = state.position.X - prev.X
		local dz = state.position.Z - prev.Z
		local mag = math.sqrt(dx*dx + dz*dz)
		if mag > 1e-3 then
			state.moveDir = Vector3.new(dx / mag, 0, dz / mag)
		end
	end
end

-- Handle player joining
function VoxelWorldService:OnPlayerAdded(player)
	-- DEFENSIVE CHECK: Ensure world is ready before spawning player
	if not self:IsWorldReady() then
		warn(string.format("[VoxelWorldService] ⚠️ World not ready when OnPlayerAdded called for %s - this should not happen!", player.Name))
		-- Don't add player if world isn't ready - they'll be kicked by Bootstrap
		return
	end

	print(string.format("[VoxelWorldService] Adding player %s to world", player.Name))

	self.players[player] = {
		position = Vector3.new(0, 0, 0),
		chunks = {},
		lastUpdate = os.clock()
	}

	-- Get spawn position from generator (Skyblock island)
	local spawnPos = Vector3.new(0, 350, 0) -- Default fallback
	if self.worldManager and self.worldManager.generator and self.worldManager.generator.GetSpawnPosition then
		local success, result = pcall(function()
			return self.worldManager.generator:GetSpawnPosition()
		end)
		if success then
			spawnPos = result
			print(string.format("[VoxelWorldService] Spawn position for %s: (%.1f, %.1f, %.1f)",
				player.Name, spawnPos.X, spawnPos.Y, spawnPos.Z))
		else
			warn(string.format("[VoxelWorldService] Failed to get spawn position for %s: %s - using fallback",
				player.Name, tostring(result)))
		end
	else
		warn(string.format("[VoxelWorldService] Generator not available for %s - using fallback spawn position",
			player.Name))
	end

	-- Spawn player after character loads
	player.CharacterAdded:Connect(function(character)
		task.wait(0.5)

		local rootPart = character:WaitForChild("HumanoidRootPart", 5)
		if rootPart then
			-- Spawn on the Skyblock island
			rootPart.CFrame = CFrame.new(spawnPos)
			print(string.format("[VoxelWorldService] Spawned character for %s at (%.1f, %.1f, %.1f)",
				player.Name, spawnPos.X, spawnPos.Y, spawnPos.Z))
		else
			warn(string.format("[VoxelWorldService] Failed to get HumanoidRootPart for %s", player.Name))
		end

		-- Notify client
		EventManager:FireEvent("PlayerEntitySpawned", player, {
			character = character
		})
	end)

	if player.Character then
		task.wait(0.5)
		local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			rootPart.CFrame = CFrame.new(spawnPos)
			print(string.format("[VoxelWorldService] Spawned existing character for %s at (%.1f, %.1f, %.1f)",
				player.Name, spawnPos.X, spawnPos.Y, spawnPos.Z))
		else
			warn(string.format("[VoxelWorldService] Failed to get HumanoidRootPart for existing character %s", player.Name))
		end

		EventManager:FireEvent("PlayerEntitySpawned", player, {
			character = player.Character
		})
	end
end

-- Handle player leaving
function VoxelWorldService:OnPlayerRemoved(player)
	if self.players[player] then
		local state = self.players[player]
		if state and state.chunks then
			for key in pairs(state.chunks) do
				self:_removeViewer(player, key)
			end
		end

		if self.blockBreakTracker then
			self.blockBreakTracker:CancelPlayer(player)
		end

		self.players[player] = nil
		self.rateLimits[player] = nil
	end
end

-- Save world data
function VoxelWorldService:SaveWorldData()
	print("===== SaveWorldData called =====")

	if not self.Deps or not self.Deps.WorldOwnershipService then
		warn("WorldOwnershipService not available for saving")
		return
	end

	local ownershipService = self.Deps.WorldOwnershipService
	local worldData = ownershipService:GetWorldData()

	if not worldData then
		warn("No world data to save")
		return
	end

	-- Collect modified chunks
	local modifiedCount = 0
	for key in pairs(self.modifiedChunks) do
		modifiedCount = modifiedCount + 1
	end
	print(string.format("Found %d modified chunks to save", modifiedCount))

	-- Start with existing saved chunks (if any)
	local chunksMap = {}
	if worldData.chunks then
		for _, chunkData in ipairs(worldData.chunks) do
			local key = string.format("%d,%d", chunkData.x, chunkData.z)
			chunksMap[key] = chunkData
			print(string.format("  Preserving existing chunk (%d,%d)", chunkData.x, chunkData.z))
		end
	end

	-- Update/add modified chunks
	for key in pairs(self.modifiedChunks) do
		local cx, cz = string.match(key, "(-?%d+),(-?%d+)")
		cx, cz = tonumber(cx), tonumber(cz)

		local chunk = self.worldManager:GetChunk(cx, cz)
		if chunk then
			local serialized = chunk:SerializeLinear()
			chunksMap[key] = {
				key = key,
				x = cx,
				z = cz,
				data = serialized
			}
			print(string.format("  Updated chunk (%d,%d)", cx, cz))
		end
	end

	-- Convert map back to array
	local chunksToSave = {}
	for _, chunkData in pairs(chunksMap) do
		table.insert(chunksToSave, chunkData)
	end

	-- Update world data
	worldData.chunks = chunksToSave
	worldData.modifiedChunkCount = #chunksToSave
	print(string.format("Prepared %d total chunks for saving", #chunksToSave))

	-- Save chest data (if ChestStorageService is available)
	if self.Deps.ChestStorageService then
		worldData.chests = self.Deps.ChestStorageService:SaveChestData()
		print(string.format("Saved %d chests", worldData.chests and #worldData.chests or 0))
	end

	-- Save through ownership service
	print("Calling WorldOwnershipService:SaveWorldData...")
	local success = ownershipService:SaveWorldData(worldData)
	if success then
		print("✅ WorldOwnershipService saved successfully")
	else
		warn("❌ WorldOwnershipService save failed!")
	end

	-- DON'T clear modified chunks - keep them in case of multiple saves
	-- The worldData already contains all chunks (modified + saved)
	-- self.modifiedChunks = {}  -- REMOVED: Causes bug where second save overwrites with 0 chunks

	print(string.format("💾 SaveWorldData complete: Saved %d chunks", #chunksToSave))
	print("=====================================")
end

-- Load world data
function VoxelWorldService:LoadWorldData()
	print("===== LoadWorldData called =====")

	if not self.Deps or not self.Deps.WorldOwnershipService then
		warn("WorldOwnershipService not available for loading")
		return
	end

	local ownershipService = self.Deps.WorldOwnershipService
	local worldData = ownershipService:GetWorldData()

	if not worldData or not worldData.chunks then
		print("No saved chunks to load")
		return
	end

	print(string.format("Found %d chunks in saved data", #worldData.chunks))

	-- Load saved chunks
	local loadedCount = 0
	local loadedChunks = {} -- Track loaded chunks to re-stream to players
	for i, chunkData in ipairs(worldData.chunks) do
		if chunkData.x and chunkData.z and chunkData.data then
			print(string.format("  Loading chunk %d/%d at (%d,%d)", i, #worldData.chunks, chunkData.x, chunkData.z))
			local chunk = self.worldManager:GetChunk(chunkData.x, chunkData.z)
			if chunk then
				chunk:DeserializeLinear(chunkData.data)
				loadedCount += 1
				table.insert(loadedChunks, {x = chunkData.x, z = chunkData.z})
				print(string.format("  ✅ Chunk (%d,%d) loaded successfully", chunkData.x, chunkData.z))
			else
				warn(string.format("  ❌ Failed to get chunk (%d,%d)", chunkData.x, chunkData.z))
			end
		end
	end

	print(string.format("✅ Loaded %d/%d saved chunks from world data", loadedCount, #worldData.chunks))

	-- Mark loaded chunks as modified so they'll be properly streamed to players
	-- This ensures clients see the restored blocks when they join
	if loadedCount > 0 then
		for _, chunkPos in ipairs(loadedChunks) do
			local key = string.format("%d,%d", chunkPos.x, chunkPos.z)
			-- Note: We don't mark as modifiedChunks (for saving) since they're already saved
			-- But we do need to ensure they're streamed to players
			print(string.format("  📝 Chunk (%d,%d) ready for streaming", chunkPos.x, chunkPos.z))
		end

		-- If players are already online (e.g., Studio reload), re-stream immediately
		local playerCount = 0
		for _ in pairs(self.players) do playerCount = playerCount + 1 end

		if playerCount > 0 then
			print(string.format("🔄 Re-streaming %d loaded chunks to %d online players...", loadedCount, playerCount))
			for player, _ in pairs(self.players) do
				for _, chunkPos in ipairs(loadedChunks) do
					self:StreamChunkToPlayer(player, chunkPos.x, chunkPos.z)
					print(string.format("  📤 Streamed chunk (%d,%d) to %s", chunkPos.x, chunkPos.z, player.Name))
				end
			end
			print("✅ Finished re-streaming loaded chunks")
		else
			print("ℹ️  No players online yet - chunks will stream when players join")
		end
	end

	-- Load chest data (if ChestStorageService is available)
	if self.Deps.ChestStorageService and worldData.chests then
		print(string.format("Loading %d chests...", #worldData.chests))
		self.Deps.ChestStorageService:LoadChestData(worldData.chests)
	end

	print("=====================================")
end

-- Get statistics
function VoxelWorldService:GetStats()
	local playerCount = 0
	for _ in pairs(self.players) do playerCount += 1 end

	return {
		players = playerCount,
		chunksStreamed = self.stats.chunksStreamed,
		chunksUnloaded = self.stats.chunksUnloaded,
		blockChanges = self.stats.blockChanges,
		modifiedChunks = self:_countModifiedChunks(),
		lastStreamTimeMs = self.stats.lastStreamTimeMs
	}
end

-- Internal: add viewer
function VoxelWorldService:_addViewer(player, key)
	if not key then return end
	local viewers = self.chunkViewers[key]
	if not viewers then
		viewers = {}
		self.chunkViewers[key] = viewers
	end
	viewers[player] = true
	self.chunkLastAccess[key] = os.clock()
end

-- Internal: remove viewer
function VoxelWorldService:_removeViewer(player, key)
	if not key then return end
	local viewers = self.chunkViewers[key]
	if viewers then
		viewers[player] = nil
		local empty = true
		for _ in pairs(viewers) do empty = false break end
		if empty then
			self.chunkViewers[key] = nil
			self.chunkLastAccess[key] = os.clock()
		end
	end
end

-- Internal: prune unused chunks
function VoxelWorldService:_pruneUnusedChunks()
	-- No-op for now - chunks are managed by viewer counts
end

-- Internal: count modified chunks
function VoxelWorldService:_countModifiedChunks()
	local count = 0
	for _ in pairs(self.modifiedChunks) do count += 1 end
	return count
end

-- Destroy service
function VoxelWorldService:Destroy()
	-- Save before shutdown
	self:SaveWorldData()
	print("VoxelWorldService: Cleanup complete")
end

return VoxelWorldService

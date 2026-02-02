--[[
	World.lua
	High-level world API: SetBlock, RemoveBlock, GetBlock, preload, save
]]

local Constants = require(script.Parent.Parent.Core.Constants)
local _Chunk = require(script.Parent.Chunk)
local WorldManager = require(script.Parent.WorldManager)
local ChunkPersistence = require(script.Parent.Parent.Storage.ChunkPersistence)

local World = {}
World.__index = World

function World.new(seed: number, worldTypeId: string?)
    local self = setmetatable({
        manager = WorldManager.new(seed, worldTypeId),
        persistence = ChunkPersistence.new({
            maxSaveQueueSize = 64,
            savesPerTick = 3,
            compressionLevel = 2
        })
    }, World)
    return self
end

-- Block API
function World:SetBlock(x: number, y: number, z: number, blockId: number): boolean
    return self.manager:SetBlock(x, y, z, blockId)
end

function World:RemoveBlock(x: number, y: number, z: number): boolean
    return self.manager:SetBlock(x, y, z, Constants.BlockType.AIR)
end

function World:GetBlock(x: number, y: number, z: number): number
    return self.manager:GetBlock(x, y, z)
end

-- Preload nearby chunks around a world position (chunk-ranged)
function World:PreloadAround(wx: number, wz: number, radius: number)
    local baseChunkX = math.floor(wx / Constants.CHUNK_SIZE_X)
    local baseChunkZ = math.floor(wz / Constants.CHUNK_SIZE_Z)

    for dx = -radius, radius do
        for dz = -radius, radius do
            self.manager:GetChunk(baseChunkX + dx, baseChunkZ + dz)
        end
    end
end

-- Save modified chunks
function World:SaveModified()
    for key, _ in pairs(self.manager:GetModifiedChunks()) do
        local cx, cz = self.manager:GetChunkCoords(key)
        local chunk = self.manager:GetChunk(cx, cz)
        if chunk then
            self.persistence:QueueChunkSave(chunk)
            self.manager:ClearModified(key)
        end
    end

    self.persistence:ProcessSaveQueue()
end

return World



--[[
	Block.lua
	Convenience wrapper around BlockRegistry
]]

local BlockRegistry = require(script.Parent.BlockRegistry)

local Block = {}

function Block.Get(blockId: number)
    return BlockRegistry:GetBlock(blockId)
end

function Block.IsSolid(blockId: number)
    return BlockRegistry:IsSolid(blockId)
end

function Block.IsTransparent(blockId: number)
    return BlockRegistry:IsTransparent(blockId)
end

function Block.Color(blockId: number)
    return BlockRegistry:GetColor(blockId)
end

return Block



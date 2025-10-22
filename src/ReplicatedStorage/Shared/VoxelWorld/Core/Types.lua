--[[
	Types.lua

	Luau type aliases for voxel engine data structures. These are consumed by
	other modules for clarity and static checking. This module returns an empty
	table to allow requiring without side-effects while exposing types.
]]

-- stylua: ignore
export type BlockId = number

export type BlockProperties = {
	solid: boolean,
	transparent: boolean,
	color: Color3?,
}

export type ChunkNeighbors = {
	north: any?,
	south: any?,
	east: any?,
	west: any?,
}

export type Chunk = {
	chunkX: number,
	chunkZ: number,
	blocks: { [number]: { [number]: { [number]: BlockId } } },
	meshPart: MeshPart?,
	editableMesh: any?,
	isDirty: boolean,
	state: string,
	isLoaded: boolean,
	neighbors: ChunkNeighbors,
	lastAccessTime: number,
}

export type PriorityQueue<T> = {
	Push: (self: PriorityQueue<T>, item: T, priority: number) -> (),
	Pop: (self: PriorityQueue<T>) -> (T?),
	Reprioritize: (self: PriorityQueue<T>, item: T, newPriority: number) -> (),
	Size: (self: PriorityQueue<T>) -> number,
}

export type ObjectPool<T> = {
	Acquire: (self: ObjectPool<T>) -> (T),
	Release: (self: ObjectPool<T>, item: T) -> (),
	Size: (self: ObjectPool<T>) -> number,
}

export type WorldManager = {
	chunks: { [string]: Chunk },
	generateQueue: PriorityQueue<any>,
	meshQueue: { any },
	playerChunkX: number,
	playerChunkZ: number,
	renderDistance: number,
	seed: number,
}

local Types = {}
return Types



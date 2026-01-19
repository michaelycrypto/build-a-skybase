<!--
PRD: Simplified World-Ready Join Flow
Owner: Core Systems
Status: Draft
Last Updated: 2026-01-19
-->

# PRD - Simplified World-Ready Join Flow

## Summary
Simplify the client/server join flow so servers only accept players after the voxel world (including schematic data) is fully initialized. Clients no longer request spawning or chunk priming; they immediately receive world state and streamed chunks, then wait for `PlayerEntitySpawned`.

## Goals
- Ensure servers are fully ready before accepting players.
- Remove client-side waiting loops and request-based spawn/chunk logic.
- Start asset loading immediately on join with no extra handshake.
- Keep join experience consistent across hub and player worlds.

## Non-Goals
- Changing the world generation algorithm.
- Reworking the networking layer beyond the join flow.
- Modifying gameplay systems unrelated to world readiness.

## Current Pain Points
- Complex client timing dependencies and retry logic.
- Request-based spawn/chunk flow adds unnecessary latency.
- Multiple waiting loops make bugs hard to reproduce.

## Proposed Flow
### Server
1. Initialize world.
2. Ensure schematic/world data is fully loaded.
3. Only then allow players to join and spawn.
4. Stream chunks immediately on player join.

### Client
1. Join server (world already ready).
2. Receive first `WorldStateChanged` immediately.
3. Start asset loading right away.
4. Wait for `PlayerEntitySpawned` to finalize spawn and begin gameplay.

## Functional Requirements
- Server blocks players until `VoxelWorldService:IsWorldReady()` is true.
- Server spawns character automatically on join (no request from client).
- Client removes all world-ready retry loops.
- Client does not request initial chunks.
- Client keeps only `PlayerEntitySpawned` as the final spawn confirmation.

## Implementation Notes
- Server will stream a first batch of chunks immediately on `OnPlayerAdded`.
- Client keeps normal `WorldStateChanged` handling but without watchdog/retry.
- Loading screen no longer waits for spawn-chunk readiness.

## Risks
- If `IsWorldReady()` returns true too early, players may still see missing chunks.
- Removing the loading hold could expose chunk streaming latency on slow machines.

## Rollout Plan
1. Ship to a staging place and validate join flow under load.
2. Monitor join latency and first-chunk timings.
3. Release to production once stable.

## Testing Plan
- Hub: join with empty cache, confirm immediate spawn and chunk streaming.
- Player world: owner join initializes world; visitor joins after owner, no kicks.
- Server restart: ensure players only spawn after world is ready.
- Verify client no longer sends `VoxelRequestInitialChunks`.

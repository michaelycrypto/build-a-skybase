--[[
	SnapshotWorker.server.lua
	Parallel worker (Actor descendant) that assembles per-receiver entity snapshot updates.
	Receives jobs via Actor:SendMessage("Assemble", jobId, entitiesArr, receiversBatch, interestRadiusSq, lastSentBundle)
	Sends results via BindableEvent at ServerScriptService/SnapshotIPC/Result:Fire(jobId, out)
]]

local ServerScriptService = game:GetService("ServerScriptService")

local actor = script:GetActor()
if not actor then
	-- If this script is not under an Actor, do nothing (environment fallback)
	return
end

-- Cache IPC event once to avoid WaitForChild per job
local resultEvent
do
    local ok, ev = pcall(function()
        local folder = ServerScriptService:FindFirstChild("SnapshotIPC") or ServerScriptService:WaitForChild("SnapshotIPC")
        return folder:FindFirstChild("Result") or folder:WaitForChild("Result")
    end)
    if ok and ev and ev:IsA("BindableEvent") then
        resultEvent = ev
    end
end

local function _round(n)
	if n >= 0 then return math.floor(n + 0.5) else return math.ceil(n - 0.5) end
end

local function _wrap360(deg)
	return ((deg % 360) + 360) % 360
end

local function _quantizePosXYZ(x, y, z)
    local step = 0.02 -- 2 cm
	return _round(x / step) * step, _round(y / step) * step, _round(z / step) * step
end

local DEG_STEP = 360 / 256

actor:BindToMessage("Assemble", function(jobId, entitiesArr, receiversBatch, interestRadiusSq, lastSentBundle, forceAll)
	-- Do not touch Instances here. Build pure-data result.
	local out = {}
	for _, r in ipairs(receiversBatch) do
		local receiverUserId = r.userId
		local currentSet = {}
		local updates = {}
		local lastUpdates = {}
		local rx, rz = r.cx, r.cz
		-- Last-sent shallow map for this receiver
		local prevMap = lastSentBundle and lastSentBundle[tostring(receiverUserId)] or nil
		for _, e in ipairs(entitiesArr) do
			local uid = e.userId
			-- Interest check
			if uid == receiverUserId then
				currentSet[uid] = true
			else
				local dx = (e.posX - (rx or e.posX))
				local dz = (e.posZ - (rz or e.posZ))
				if (dx * dx + dz * dz) <= interestRadiusSq then
					currentSet[uid] = true
				end
			end
			-- Delta-gate (self always considered)
			local qx, qy, qz = _quantizePosXYZ(e.posX, e.posY, e.posZ)
			local qyaw = _round(_wrap360(e.yaw) / DEG_STEP) * DEG_STEP
			local qpitch = _round(_wrap360(e.pitch) / DEG_STEP) * DEG_STEP
			local prev = prevMap and prevMap[tostring(uid)]
			local changed = (forceAll == true) or (uid == receiverUserId)
			if not changed then
				if not prev then
					changed = true
				else
					changed = (prev.px ~= qx) or (prev.py ~= qy) or (prev.pz ~= qz)
						or (prev.yaw ~= qyaw) or (prev.pitch ~= qpitch)
						or (prev.g ~= (e.grounded and true or false))
						or (prev.sn ~= (e.sneak and true or false))
						or (prev.s ~= (e.sprint and true or false))  -- BUG FIX: Check sprint changes!
				end
			end
			if changed and (uid == receiverUserId or currentSet[uid]) then
				updates[#updates + 1] = {
					userId = uid,
					position = Vector3.new(qx, qy, qz),
					velocity = Vector3.new(e.velX, e.velY, e.velZ),
					yaw = qyaw,
					pitch = qpitch,
					grounded = e.grounded and true or false,
					sneak = e.sneak and true or false,
					sprint = e.sprint and true or false,  -- BUG FIX: Include sprint in updates!
					stateFlags = 0
				}
				lastUpdates[tostring(uid)] = { px = qx, py = qy, pz = qz, yaw = qyaw, pitch = qpitch, g = e.grounded and true or false, sn = e.sneak and true or false, s = e.sprint and true or false }
			end
		end
		out[#out + 1] = { receiverUserId = receiverUserId, current = currentSet, updates = updates, last = lastUpdates }
	end
	-- Synchronize and fire result event
	if resultEvent then
		resultEvent:Fire(jobId, out)
	end
end)



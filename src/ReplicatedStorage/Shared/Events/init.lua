local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EventFolder = ReplicatedStorage:FindFirstChild("Events") or Instance.new("Folder", ReplicatedStorage)
EventFolder.Name = "Events"

local events = {}

local function ensureEvent(name)
	local evt = EventFolder:FindFirstChild(name)
	if not evt then
		evt = Instance.new("RemoteEvent")
		evt.Name = name
		evt.Parent = EventFolder
	end
	return evt
end

function events.Get(name)
	return ensureEvent(name)
end

return events


-- One multiplexed RemoteEvent each way, plus an unreliable channel for camera look samples.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}
local handlers = {}

local folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		local e = Instance.new("RemoteEvent")
		e.Name = "E"
		e.Parent = folder
		local u = Instance.new("UnreliableRemoteEvent")
		u.Name = "U"
		u.Parent = folder
		folder.Parent = ReplicatedStorage
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

local E = folder:WaitForChild("E")
local U = folder:WaitForChild("U")

local function dispatch(name, ...)
	local list = handlers[name]
	if list then
		for _, fn in ipairs(list) do
			task.spawn(fn, ...)
		end
	end
end

function Net.on(name, fn)
	handlers[name] = handlers[name] or {}
	table.insert(handlers[name], fn)
end

if RunService:IsServer() then
	E.OnServerEvent:Connect(function(player, name, ...)
		if type(name) == "string" then
			dispatch(name, player, ...)
		end
	end)
	U.OnServerEvent:Connect(function(player, name, ...)
		if type(name) == "string" then
			dispatch(name, player, ...)
		end
	end)

	function Net.fire(player, name, ...)
		E:FireClient(player, name, ...)
	end
	function Net.fireAll(name, ...)
		E:FireAllClients(name, ...)
	end
else
	E.OnClientEvent:Connect(function(name, ...)
		dispatch(name, ...)
	end)
	function Net.send(name, ...)
		E:FireServer(name, ...)
	end
	function Net.sendUnreliable(name, ...)
		U:FireServer(name, ...)
	end
end

return Net

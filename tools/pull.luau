-- Run inside Studio (edit mode) via the MCP execute_luau tool while `node tools/sync.js` is running.
-- Pulls src/ into the place using the same layout as default.project.json / Lync.
local HttpService = game:GetService("HttpService")
local wasEnabled = HttpService.HttpEnabled
HttpService.HttpEnabled = true
local ok, body = pcall(HttpService.GetAsync, HttpService, "http://127.0.0.1:34875/bundle", true)
HttpService.HttpEnabled = wasEnabled
assert(ok, body)
local data = HttpService:JSONDecode(body)

local CLASS = { Script = "Script", ClientScript = "Script", LocalScript = "LocalScript", ModuleScript = "ModuleScript", Folder = "Folder" }
local seen = {}
local mounts = {}
local count = 0

local function resolveParent(path)
	local inst = game
	for i = 1, #path - 1 do
		local name = path[i]
		local child = inst:FindFirstChild(name)
		if not child then
			if inst == game then
				child = game:GetService(name)
			else
				child = Instance.new("Folder")
				child.Name = name
				child.Parent = inst
			end
		end
		inst = child
	end
	return inst
end

for _, item in ipairs(data.items) do
	local parent = resolveParent(item.path)
	local name = item.path[#item.path]
	local className = CLASS[item.kind]
	local inst = parent:FindFirstChild(name)
	if inst and inst.ClassName ~= className then
		local kids = inst:GetChildren()
		local replacement = Instance.new(className)
		replacement.Name = name
		for _, k in ipairs(kids) do
			k.Parent = replacement
		end
		inst:Destroy()
		inst = replacement
		inst.Parent = parent
	elseif not inst then
		inst = Instance.new(className)
		inst.Name = name
		inst.Parent = parent
	end
	if item.kind == "ClientScript" then
		inst.RunContext = Enum.RunContext.Client
	end
	if item.source and inst.Source ~= item.source then
		inst.Source = item.source
		count += 1
	end
	seen[inst] = true
	if item.mount then
		table.insert(mounts, inst)
	end
end

local removed = 0
for _, m in ipairs(mounts) do
	for _, d in ipairs(m:GetDescendants()) do
		if d.Parent and not seen[d] and (d:IsA("LuaSourceContainer") or d:IsA("Folder")) then
			d:Destroy()
			removed += 1
		end
	end
end
return string.format("synced %d items, %d sources changed, %d removed", #data.items, count, removed)

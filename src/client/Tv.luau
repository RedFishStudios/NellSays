-- The den CRT and the HUD broadcast insert: a live mirror of Nell's stage (including puppets).
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Ui = require(script.Parent.Ui)

local Tv = {}
local gs = ReplicatedStorage:WaitForChild("GameState")
local studio, stage, worldNell
local feeds = {} -- each: { frame, vp, world, cam, nell, nellBase, overlay }
local exprStart = 0
local dropStart = -100
local lastTvMode = "off"

local function exprParts(model, tag)
	local list = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("Expr") == tag then
			table.insert(list, d)
		end
	end
	return list
end

local function applyExpr(nell, expr, t)
	if not nell then
		return
	end
	local smiling = expr == "smile" or expr == "slack"
	for _, p in ipairs(exprParts(nell, "idle")) do
		p.Transparency = smiling and 1 or 0
	end
	-- smile appears progressively as the strings pull (first ~2s)
	local k = smiling and math.clamp(t / 2, 0, 1) or 0
	for _, p in ipairs(exprParts(nell, "smile")) do
		p.Transparency = smiling and (1 - k) or 1
	end
	-- blood streams grow from the eyes down to the collar over ~4s
	local b = smiling and math.clamp((t - 0.8) / 4, 0, 1) or 0
	local pivot = nell:GetPivot()
	for _, p in ipairs(exprParts(nell, "blood")) do
		local rel = p:GetAttribute("BaseRel")
		if rel then
			local len = 0.05 + b * 1.05
			p.Size = Vector3.new(0.07, len, 0.04)
			p.CFrame = pivot * rel * CFrame.new(0, -len / 2, 0)
			p.Transparency = b > 0 and 0 or 1
		end
	end
end

local function nellOffset(now, expr)
	local bob = math.sin(now * 1.6) * 0.08
	local sway = math.sin(now * 0.7) * 0.06
	local drop = math.clamp((now - dropStart) / 2.2, 0, 1)
	local dropY = (1 - drop) ^ 2 * 7
	if expr == "slack" then
		return CFrame.new(0, -0.6, 0) * CFrame.Angles(math.rad(18), 0, math.rad(12))
	end
	local tilt = (expr == "smile") and math.rad(9) or 0
	return CFrame.new(0, bob + dropY, 0) * CFrame.Angles(0, sway, tilt)
end

local function cloneStage(world)
	world:ClearAllChildren()
	for _, child in ipairs(stage:GetChildren()) do
		if child.Name ~= "Puppets" then
			local ok, c = pcall(function()
				child.Archivable = true
				return child:Clone()
			end)
			if ok and c then
				c.Parent = world
			end
		end
	end
	local pf = Instance.new("Folder")
	pf.Name = "Puppets"
	pf.Parent = world
	for _, pup in ipairs(stage.Puppets:GetChildren()) do
		pup.Archivable = true
		local ok, c = pcall(function()
			return pup:Clone()
		end)
		if ok and c then
			c.Parent = pf
		end
	end
	-- the Puppeteer's arms reaching down above Nell (Last Broadcast)
	local arms = Instance.new("Folder")
	arms.Name = "Arms"
	arms.Parent = world
	local np = studio:GetAttribute("NellPivot")
	for _, side in ipairs({ -1, 1 }) do
		local a = Instance.new("Part")
		a.Anchored = true
		a.Size = Vector3.new(0.5, 7, 0.5)
		a.Color = Color3.fromRGB(18, 18, 20)
		a.CFrame = np * CFrame.new(side * 2.2, 12.5, 0.5) * CFrame.Angles(0, 0, side * 0.25)
		a.Parent = arms
		local h = Instance.new("Part")
		h.Anchored = true
		h.Size = Vector3.new(0.7, 1, 0.35)
		h.Color = Color3.fromRGB(200, 180, 140)
		h.CFrame = np * CFrame.new(side * 1.4, 9, 0.5)
		h.Parent = arms
	end
	return world:FindFirstChild("Nell")
end

local function makeFeed(parent, size, pos, zindex)
	local frame = Ui.new("Frame", {
		Size = size,
		Position = pos or UDim2.new(),
		BackgroundColor3 = Color3.new(0, 0, 0),
		ClipsDescendants = true,
		ZIndex = zindex or 1,
		Parent = parent,
	})
	local vp = Ui.new("ViewportFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(8, 6, 6),
		Ambient = Color3.fromRGB(150, 120, 100),
		LightColor = Color3.fromRGB(255, 220, 180),
		LightDirection = Vector3.new(0.3, -1, 0.6),
		ZIndex = zindex or 1,
		Parent = frame,
	})
	local world = Instance.new("WorldModel")
	world.Parent = vp
	local cam = Instance.new("Camera")
	cam.FieldOfView = 42
	cam.Parent = vp
	vp.CurrentCamera = cam
	-- overlay for static / symbols / scanlines
	local overlay = Ui.new(
		"Frame",
		{ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = (zindex or 1) + 1, Parent = frame }
	)
	local noise = {}
	for i = 1, 40 do
		noise[i] = Ui.new("Frame", {
			Size = UDim2.fromScale(math.random() * 0.6 + 0.2, 0.02 + math.random() * 0.04),
			Position = UDim2.fromScale(math.random(), math.random()),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 1,
			ZIndex = (zindex or 1) + 2,
			Parent = overlay,
		})
	end
	local big = Ui.label({
		Size = UDim2.fromScale(1, 1),
		TextScaled = true,
		Text = "",
		Font = Ui.Theme.Bold,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Color3.fromRGB(255, 245, 220),
		ZIndex = (zindex or 1) + 3,
		Parent = overlay,
	})
	local small = Ui.label({
		Size = UDim2.new(1, -10, 0.14, 0),
		Position = UDim2.new(0, 6, 0.84, 0),
		TextScaled = true,
		Text = "",
		Font = Ui.Theme.Mono,
		TextColor3 = Color3.fromRGB(255, 80, 80),
		ZIndex = (zindex or 1) + 3,
		Parent = overlay,
	})
	local scan = Ui.new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.85),
			NumberSequenceKeypoint.new(0.5, 1),
			NumberSequenceKeypoint.new(1, 0.85),
		}),
	})
	local vignette = Ui.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.4,
		ZIndex = (zindex or 1) + 1,
		Parent = overlay,
	}, { scan })
	local feed = {
		frame = frame,
		vp = vp,
		world = world,
		cam = cam,
		noise = noise,
		big = big,
		small = small,
		vignette = vignette,
	}
	feed.nell = cloneStage(world)
	feed.nellBase = Tv.base
	table.insert(feeds, feed)
	return feed
end

local function refreshPuppets()
	for _, f in ipairs(feeds) do
		f.nell = cloneStage(f.world)
		f.nellBase = Tv.base
	end
end

function Tv.init(hudRoot)
	studio = workspace:WaitForChild("StudioSet")
	stage = studio:WaitForChild("Stage")
	stage:WaitForChild("Nell")
	stage:WaitForChild("Puppets")
	worldNell = stage.Nell
	local worldBase = worldNell:GetPivot()
	Tv.base = worldBase
	for _, p in ipairs(exprParts(worldNell, "blood")) do
		p:SetAttribute("BaseRel", worldBase:Inverse() * p.CFrame)
	end
	-- den CRT surface
	local screen = workspace:WaitForChild("House"):WaitForChild("Props"):WaitForChild("CRTScreen")
	local sg = Instance.new("SurfaceGui")
	sg.Name = "CRTGui"
	sg.Face = Enum.NormalId.Back
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 60
	sg.LightInfluence = 0
	sg.Brightness = 1.6
	sg.Adornee = screen
	sg.Parent = game:GetService("Players").LocalPlayer.PlayerGui
	makeFeed(sg, UDim2.fromScale(1, 1))
	-- HUD insert (shown during key broadcast beats)
	local insert = Ui.new("Frame", {
		Name = "Insert",
		Size = UDim2.new(0, 300, 0, 225),
		Position = UDim2.new(1, -316, 0, 70),
		BackgroundColor3 = Color3.fromRGB(10, 10, 10),
		Visible = false,
		Parent = hudRoot,
	}, { Ui.corner(10), Ui.stroke(Color3.fromRGB(160, 160, 165), 3) })
	local f2 = makeFeed(insert, UDim2.new(1, -8, 1, -8), UDim2.fromOffset(4, 4), 5)
	Ui.label({
		Text = "● LIVE  NELL SAYS",
		Size = UDim2.new(1, -10, 0, 18),
		Position = UDim2.fromOffset(10, 6),
		TextColor3 = Color3.fromRGB(255, 70, 70),
		Font = Ui.Theme.Bold,
		TextSize = 14,
		ZIndex = 20,
		Parent = insert,
	})
	Tv.insert = insert
	-- edit-room monitor
	local mon = workspace.House.Props:WaitForChild("EditMonitor")
	local mg = Instance.new("SurfaceGui")
	mg.Face = Enum.NormalId.Front
	mg.LightInfluence = 0
	mg.Adornee = mon
	mg.Parent = game:GetService("Players").LocalPlayer.PlayerGui
	local monLabel = Ui.label({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 0,
		BackgroundColor3 = Color3.new(0, 0, 0),
		TextScaled = true,
		Font = Ui.Theme.Mono,
		TextColor3 = Color3.fromRGB(120, 255, 140),
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "",
		Parent = mg,
	})

	stage.Puppets.ChildAdded:Connect(function()
		task.wait(0.4)
		refreshPuppets()
	end)
	stage.Puppets.ChildRemoved:Connect(function()
		task.defer(refreshPuppets)
	end)

	gs:GetAttributeChangedSignal("NellExpr"):Connect(function()
		exprStart = os.clock()
	end)
	gs:GetAttributeChangedSignal("TV"):Connect(function()
		local mode = gs:GetAttribute("TV")
		if
			mode == "nell"
			and (lastTvMode == "static" or lastTvMode == "off")
			and (gs:GetAttribute("ChapterIndex") or 0) <= 1
		then
			dropStart = os.clock()
		end
		lastTvMode = mode
	end)

	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local expr = gs:GetAttribute("NellExpr") or "idle"
		local mode = gs:GetAttribute("TV") or "off"
		local t = now - exprStart
		local off = nellOffset(now, expr)
		worldNell:PivotTo(worldBase * off)
		applyExpr(worldNell, expr, t)
		local wide = gs:GetAttribute("TVWide") or mode == "puppets" or (gs:GetAttribute("PuppetCount") or 0) > 0
		local camCF = (mode == "eyes" and studio:GetAttribute("EyesCam"))
			or (wide and studio:GetAttribute("WideCam"))
			or studio:GetAttribute("TvCam")
		local sym = gs:GetAttribute("TVSymbol") or ""
		mon:FindFirstChildOfClass("SurfaceGui")
		local monMode = gs:GetAttribute("EditMonitor") or ""
		monLabel.Text = monMode == "cupboard" and "CAM 3: LINEN CUPBOARD\n▮▮ (door ajar)" or "REC ●"
		for _, f in ipairs(feeds) do
			if f.nell and f.nellBase then
				f.nell:PivotTo(f.nellBase * off)
				applyExpr(f.nell, expr, t)
			end
			local armsF = f.world:FindFirstChild("Arms")
			if armsF then
				for _, a in ipairs(armsF:GetChildren()) do
					a.Transparency = gs:GetAttribute("NellArms") and 0 or 1
				end
			end
			f.cam.CFrame = camCF
			f.cam.FieldOfView = wide and 55 or (mode == "eyes" and 30 or 42)
			local showStatic = mode == "static" or mode == "off"
			for _, n in ipairs(f.noise) do
				if mode == "static" then
					n.BackgroundTransparency = math.random() < 0.5 and 0.2 or 0.9
					n.Position = UDim2.fromScale(math.random() * 0.6, math.random())
				else
					n.BackgroundTransparency = 1
				end
			end
			f.vp.Visible = not showStatic and mode ~= "cupboard"
			f.frame.BackgroundColor3 = mode == "static" and Color3.fromRGB(70, 70, 70) or Color3.new(0, 0, 0)
			f.vp.ImageColor3 = mode == "frozen" and Color3.fromRGB(150, 170, 255) or Color3.new(1, 1, 1)
			if mode == "cupboard" then
				f.big.Text = "□\nupstairs cupboard"
				f.big.TextColor3 = Color3.fromRGB(200, 220, 255)
			elseif mode == "eject" then
				f.big.Text = "⏏"
				f.big.TextColor3 = Color3.fromRGB(255, 245, 220)
			elseif sym ~= "" and Config.Symbols[sym] then
				f.big.Text = Config.Symbols[sym].glyph
				f.big.TextColor3 = Config.Symbols[sym].color
			else
				f.big.Text = ""
			end
			f.small.Text = mode == "frozen" and "▶ PLAY   00:00:00"
				or ((mode == "nell" or mode == "eyes" or mode == "puppets") and "● NELL SAYS" or "")
		end
	end)
end

function Tv.showInsert(seconds)
	if not Tv.insert then
		return
	end
	Tv.insert.Visible = true
	local token = os.clock()
	Tv._insertToken = token
	task.delay(seconds or 4, function()
		if Tv._insertToken == token then
			Tv.insert.Visible = false
		end
	end)
end

return Tv

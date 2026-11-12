-- Camera ownership: cutscenes > hide peek > spectate > normal first person.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)
local Ui = require(script.Parent.Ui)
local Controls = require(script.Parent.Controls)
local Tv = require(script.Parent.Tv)
local T = Ui.Theme

local Cinema = {}
local player = Players.LocalPlayer
local gs = ReplicatedStorage:WaitForChild("GameState")
local cam = workspace.CurrentCamera
local root
local bars, fade, title, sub
local playing = 0 -- token
local shot = nil -- function(dt) -> CFrame
local hideView = nil -- { cf, yaw, pitch }
local spectate = { index = 1, tv = false }
Cinema.active = false

local function setLetterbox(on)
	for _, b in ipairs(bars) do
		TweenService:Create(b, TweenInfo.new(0.4), { Size = UDim2.new(1, 0, on and 0.11 or 0, 0) }):Play()
	end
end

local function fadeTo(alpha, time, color)
	fade.BackgroundColor3 = color or Color3.new(0, 0, 0)
	TweenService:Create(fade, TweenInfo.new(time or 0.4), { BackgroundTransparency = 1 - alpha }):Play()
end
Cinema.fadeTo = fadeTo

local function caption(text, subtext)
	title.Text = text or ""
	sub.Text = subtext or ""
end

local function begin()
	playing += 1
	Cinema.active = true
	Controls.locked = true
	cam.CameraType = Enum.CameraType.Scriptable
	setLetterbox(true)
	return playing
end

local function finish(token)
	if token ~= playing then
		return
	end
	Cinema.active = false
	Controls.locked = false
	shot = nil
	setLetterbox(false)
	caption("", "")
	fadeTo(0, 0.6)
	cam.FieldOfView = 70
	if not hideView then
		cam.CameraType = Enum.CameraType.Custom
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			cam.CameraSubject = hum
		end
	end
end

local function hold(cf, fov)
	shot = function()
		return cf
	end
	cam.FieldOfView = fov or 70
end

local function pan(fromCF, toCF, seconds, fov)
	local t0 = os.clock()
	shot = function()
		local a = math.clamp((os.clock() - t0) / seconds, 0, 1)
		a = a * a * (3 - 2 * a)
		return fromCF:Lerp(toCF, a)
	end
	cam.FieldOfView = fov or 70
end

local function follow(fn, fov)
	shot = fn
	cam.FieldOfView = fov or 70
end

local function waitFor(token, seconds)
	local t0 = os.clock()
	while os.clock() - t0 < seconds do
		if token ~= playing then
			return false
		end
		task.wait()
	end
	return true
end

local function charHead(userId)
	local p = Players:GetPlayerByUserId(userId)
	local c = p and p.Character
	return c and c:FindFirstChild("Head"), c
end

---------------------------------------------------------------- intro
local function intro(args)
	local tok = begin()
	fadeTo(1, 0)
	local LA = CFrame.lookAt
	local function V(x, y, z)
		return Vector3.new(x, y, z)
	end
	local function hostFace()
		local head = charHead(args.host)
		if head then
			return LA(head.Position + head.CFrame.LookVector * 4 + V(0, 0.3, 0), head.Position)
		end
		return LA(V(16, 5, 18), V(16, 4, 12))
	end
	-- DVD prop in the host's hand (local only)
	local dvd
	local head, hostChar = charHead(args.host)
	if hostChar then
		local hand = hostChar:FindFirstChild("RightHand") or hostChar:FindFirstChild("Right Arm")
		if hand then
			dvd = Instance.new("Part")
			dvd.Size = Vector3.new(0.9, 1.2, 0.12)
			dvd.Color = Color3.fromRGB(40, 70, 170)
			dvd.CanCollide = false
			dvd.Massless = true
			dvd.CFrame = hand.CFrame * CFrame.new(0, -0.6, -0.3)
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = dvd, hand
			w.Parent = dvd
			dvd.Parent = hostChar
		end
	end
	local script
	if args.quick then
		script = {
			{
				0,
				function()
					fadeTo(0, 1)
					pan(LA(V(6, 6, 6), V(6, 6, 0)), LA(V(30, 3, 10), V(38, 1, 1)), 3)
					caption("Forbidden Disc", "Rain on the window. Mum and Dad are out.")
				end,
			},
			{
				3,
				function()
					follow(hostFace)
				end,
			},
			{
				6,
				function()
					hold(LA(V(21, 4, 6), V(19.8, 2.7, 2.2)), 50)
					caption("", "The tray slides shut.")
				end,
			},
			{
				6.6,
				function()
					hold(LA(V(38, 5.5, 10), V(38, 5, 0)), 60)
					caption("", "The front door slams. The deadbolt turns by itself.")
				end,
			},
			{
				10.5,
				function()
					pan(LA(V(30, 6, 14), V(16, 4.5, 4)), LA(V(16, 4.8, 10.5), V(16, 4.5, 4.4)), 2.5, 55)
					caption("", "The TV starts by itself.")
				end,
			},
			{
				14,
				function()
					hold(LA(V(16, 4.6, 8.2), V(16, 4.5, 4.4)), 45)
					caption("", "")
				end,
			},
			{
				20.5,
				function()
					fadeTo(1, 0.8)
				end,
			},
			{ 22.5, nil },
		}
	else
		script = {
			{
				0,
				function()
					fadeTo(0, 1.5)
					pan(LA(V(6, 6, 7), V(6, 6, 0)), LA(V(7, 5.5, 4), V(4, 6, 0)), 5, 60)
					caption("Forbidden Disc", "Rain on the front window. A quiet clock.")
				end,
			},
			{
				5,
				function()
					pan(LA(V(33, 3, 8), V(42, 0.8, 0)), LA(V(33, 4, 8), V(31, 4, 2)), 6, 60)
					caption("", "Shoes and backpacks by the hall console.")
				end,
			},
			{
				11,
				function()
					follow(hostFace, 55)
					caption("", "The host holds up a plain blue DVD case.")
				end,
			},
			{
				19,
				function()
					pan(LA(V(16, 5, 18), V(16, 4, 10)), LA(V(20, 5, 14), V(14, 3.5, 10)), 5, 60)
					caption("", "A scratched label: NELL SAYS")
				end,
			},
			{
				24,
				function()
					hold(LA(V(21.5, 3.6, 5.5), V(19.8, 2.7, 2.2)), 40)
					caption("", "The disc slides into the silver tray.")
				end,
			},
			{
				24.6,
				function()
					hold(LA(V(38, 5.5, 10), V(38, 5, 0)), 60)
					caption("", "SLAM. The deadbolt turns by itself.")
				end,
			},
			{
				29,
				function()
					pan(LA(V(40, 5.5, 3), V(40.8, 5.2, 0.4)), LA(V(38, 5, 5), V(38, 4, 0)), 5, 50)
					caption("", "The handle will not move.")
				end,
			},
			{
				36,
				function()
					hold(LA(V(68, 7, 3), V(85, -2, -14)), 50)
					caption("", "Outside, the side gate slams too.")
				end,
			},
			{
				40,
				function()
					pan(LA(V(24, 6, 18), V(16, 4.5, 4)), LA(V(16, 4.8, 11), V(16, 4.5, 4.4)), 3.5, 55)
					caption("", "The TV turns itself on.")
				end,
			},
			{
				44,
				function()
					hold(LA(V(16, 4.6, 8.2), V(16, 4.5, 4.4)), 45)
					caption("", "Five strings lower a wooden marionette.")
				end,
			},
			{
				55,
				function()
					pan(LA(V(16, 4.6, 8.2), V(16, 4.5, 4.4)), LA(V(16, 4.6, 9.5), V(16, 4.5, 4.4)), 9, 45)
					caption("", "On screen, the room is frozen. You are not.")
				end,
			},
			{
				64,
				function()
					hold(LA(V(16, 4.55, 7.4), V(16, 4.5, 4.4)), 40)
					caption("", "")
				end,
			},
			{
				68.5,
				function()
					fadeTo(1, 1)
				end,
			},
			{ 70, nil },
		}
	end
	local t0 = os.clock()
	for _, step in ipairs(script) do
		local remaining = step[1] - (os.clock() - t0)
		if remaining > 0 and not waitFor(tok, remaining) then
			break
		end
		if step[2] then
			step[2]()
		end
	end
	if dvd then
		dvd:Destroy()
	end
	if tok == playing then
		finish(tok)
	end
end

---------------------------------------------------------------- death (7.5s, every client including spectators)
local function death(args)
	local tok = begin()
	Net.send("Ack", "death")
	local victimPos = args.pos
	local door = args.door
	local side = (door - victimPos)
	side = Vector3.new(side.X, 0, side.Z)
	side = side.Magnitude > 0.1 and side.Unit or Vector3.new(1, 0, 0)
	local perp = Vector3.new(-side.Z, 0, side.X)
	local floorY = victimPos.Y - 3
	local mid = (victimPos + door) / 2
	local camPos = Vector3.new(mid.X, floorY + 1.6, mid.Z) + perp * 11
	-- keep the camera inside the room if possible
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local chars = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(chars, p.Character)
		end
	end
	params.FilterDescendantsInstances = chars
	local fromP = Vector3.new(mid.X, floorY + 1.6, mid.Z)
	local hit = workspace:Raycast(fromP, camPos - fromP, params)
	if hit then
		camPos = hit.Position - (camPos - fromP).Unit * 1
	end
	caption(("Player %d — %s"):format(args.slot or 0, args.name or ""), args.cause or "")
	local lighting = game:GetService("Lighting")
	local oldBright = lighting.Brightness
	follow(function()
		local head = charHead(args.userId)
		local target = head and head.Position or victimPos
		return CFrame.lookAt(camPos, target:Lerp(door + Vector3.new(0, 2, 0), 0.25))
	end, 62)
	task.delay(0.25, function()
		lighting.Brightness = 0.15
	end)
	if not waitFor(tok, 3.5) then
		lighting.Brightness = oldBright
		return
	end
	-- inside the dark room on the set
	hold(args.darkCam, 55)
	caption("", "")
	if not waitFor(tok, 1.5) then
		lighting.Brightness = oldBright
		return
	end
	fadeTo(1, 0.15)
	if not waitFor(tok, 0.3) then
		lighting.Brightness = oldBright
		return
	end
	-- TV stage reveal: the new puppet beside Nell
	lighting.Brightness = oldBright
	hold(args.stageCam, 50)
	Tv.showInsert(2.4)
	fadeTo(0, 0.4)
	caption("", ("Player %d is part of the show now."):format(args.slot or 0))
	waitFor(tok, 2.3)
	finish(tok)
end

---------------------------------------------------------------- misc shots
local function chapterCard(args)
	title.Text = ("CHAPTER %d"):format(args.index)
	sub.Text = args.name:upper()
	title.TextTransparency = 0
	task.delay(2.4, function()
		if not Cinema.active then
			caption("", "")
		end
	end)
end

local function toSet()
	local tok = begin()
	fadeTo(1, 0.8, Color3.new(1, 1, 1))
	waitFor(tok, 1.6)
	finish(tok)
	fadeTo(0, 1)
end

local function stageShot(seconds, text, fov)
	local tok = begin()
	local studio = workspace:FindFirstChild("StudioSet")
	if studio then
		hold(studio:GetAttribute("WideCam"), fov or 60)
	end
	caption("", text or "")
	waitFor(tok, seconds)
	finish(tok)
end

local function offAirEnd()
	local tok = begin()
	pan(
		CFrame.lookAt(Vector3.new(38, 6, -32), Vector3.new(38, 8, 10)),
		CFrame.lookAt(Vector3.new(38, 7, -22), Vector3.new(16, 4.5, 4)),
		3,
		50
	)
	caption("OFF AIR", "The CRT glows once with the motionless cast, then closes to a white dot.")
	waitFor(tok, 3)
	fadeTo(1, 0.6, Color3.new(1, 1, 1))
	waitFor(tok, 1)
	finish(tok)
end

---------------------------------------------------------------- hide peek
Net.on("HideEnter", function(peekCF)
	hideView = { cf = peekCF, yaw = 0, pitch = 0 }
	cam.CameraType = Enum.CameraType.Scriptable
	Controls.locked = true
end)
Net.on("HideExit", function()
	hideView = nil
	Controls.locked = Cinema.active
	if not Cinema.active then
		cam.CameraType = Enum.CameraType.Custom
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			cam.CameraSubject = hum
		end
	end
end)

---------------------------------------------------------------- spectate
function Cinema.spectateNext(d)
	spectate.tv = false
	spectate.index += d
end
function Cinema.spectateTv()
	spectate.tv = not spectate.tv
end
local function livingOthers()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if
			p ~= player
			and p:GetAttribute("Alive")
			and p.Character
			and p.Character:FindFirstChildOfClass("Humanoid")
		then
			table.insert(list, p)
		end
	end
	table.sort(list, function(a, b)
		return (a:GetAttribute("Slot") or 9) < (b:GetAttribute("Slot") or 9)
	end)
	return list
end
function Cinema.spectateTarget()
	local list = livingOthers()
	if spectate.tv or #list == 0 then
		return nil
	end
	local i = (spectate.index - 1) % #list + 1
	return list[i]
end
local function isSpectating()
	local phase = gs:GetAttribute("Phase")
	return (phase == "Playing" or phase == "Vote") and player:GetAttribute("Alive") == false
end
Cinema.isSpectating = isSpectating

---------------------------------------------------------------- init
function Cinema.init(hudRoot)
	root = hudRoot
	bars = {
		Ui.new(
			"Frame",
			{ Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = Color3.new(0, 0, 0), ZIndex = 50, Parent = root }
		),
		Ui.new("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			ZIndex = 50,
			Parent = root,
		}),
	}
	fade = Ui.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 40,
		Parent = root,
	})
	title = Ui.label({
		Text = "",
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.new(0, 0, 0.12, 0),
		Font = T.Bold,
		TextSize = 34,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = T.Nell,
		ZIndex = 60,
		Parent = root,
	})
	sub = Ui.label({
		Text = "",
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 0, 0.12, 44),
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = T.Text,
		ZIndex = 60,
		Parent = root,
	})
	for _, l in ipairs({ title, sub }) do
		Ui.stroke(Color3.new(0, 0, 0), 1.5).Parent = l
	end

	Net.on("Cine", function(name, args)
		if name == "Intro" then
			task.spawn(intro, args)
		elseif name == "IntroEnd" then
			playing += 1
			finish(playing)
			fadeTo(0, 0.8)
		elseif name == "Death" then
			task.spawn(death, args)
		elseif name == "Insert" then
			Tv.showInsert(args.seconds)
		elseif name == "Chapter" then
			chapterCard(args)
		elseif name == "ToSet" then
			task.spawn(toSet)
		elseif name == "Transform" then
			task.spawn(stageShot, 18, "Strings lower from above and lift each survivor upright.", 60)
		elseif name == "FullCast" then
			task.spawn(stageShot, 6, "Every avatar hangs upright by visible strings around Nell.", 66)
		elseif name == "OffAirEnd" then
			task.spawn(offAirEnd)
		elseif name == "Reset" then
			playing += 1
			hideView = nil
			finish(playing)
			fadeTo(0, 0.3)
		end
	end)

	RunService:BindToRenderStep("HushCamera", Enum.RenderPriority.Camera.Value + 1, function()
		if Cinema.active and shot then
			cam.CameraType = Enum.CameraType.Scriptable
			cam.CFrame = shot()
			return
		end
		if hideView then
			cam.CameraType = Enum.CameraType.Scriptable
			local delta = UserInputService:GetMouseDelta()
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			hideView.yaw = math.clamp(hideView.yaw - delta.X * 0.004, -0.7, 0.7)
			hideView.pitch = math.clamp(hideView.pitch - delta.Y * 0.004, -0.35, 0.35)
			cam.CFrame = hideView.cf * CFrame.Angles(0, hideView.yaw, 0) * CFrame.Angles(hideView.pitch, 0, 0)
			cam.FieldOfView = 75
			return
		end
		if isSpectating() then
			local target = Cinema.spectateTarget()
			if target then
				local hum = target.Character:FindFirstChildOfClass("Humanoid")
				if cam.CameraSubject ~= hum then
					cam.CameraType = Enum.CameraType.Custom
					cam.CameraSubject = hum
				end
			else
				local studio = workspace:FindFirstChild("StudioSet")
				if studio then
					cam.CameraType = Enum.CameraType.Scriptable
					cam.CFrame = studio:GetAttribute("WideCam")
					cam.FieldOfView = 60
				end
			end
		end
	end)
end

return Cinema

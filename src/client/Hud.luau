-- In-game HUD. Every audio cue has a visible equivalent so the game is playable muted.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config)
local Ui = require(script.Parent.Ui)
local Audio = require(script.Parent.Audio)
local Controls = require(script.Parent.Controls)
local Cinema = require(script.Parent.Cinema)
local T = Ui.Theme

local Hud = {}
local player = Players.LocalPlayer
local gs = ReplicatedStorage:WaitForChild("GameState")
local root

local SOURCE_COLORS = {
	TV = Color3.fromRGB(214, 168, 86),
	PHONE = Color3.fromRGB(120, 190, 255),
	UPSTAIRS = Color3.fromRGB(200, 120, 255),
	ROOM = Color3.fromRGB(170, 170, 170),
	STAGE = Color3.fromRGB(255, 120, 120),
}

local function fmtTime(s)
	s = math.max(0, math.ceil(s))
	return ("%d:%02d"):format(s // 60, s % 60)
end

local function slotColor(slot)
	local s = Config.Slots[slot]
	return s and s.color or T.Dim
end

---------------------------------------------------------------- results queue (sounds spaced by a short beat)
local resultQueue = {}
local resultBusy = false
local resultFrame, resultIcon, resultTitle, resultDetail
local function showResult(kind, title, detail)
	table.insert(resultQueue, { kind = kind, title = title, detail = detail })
	if resultBusy then
		return
	end
	resultBusy = true
	task.spawn(function()
		while #resultQueue > 0 do
			local r = table.remove(resultQueue, 1)
			local good = r.kind == "ding"
			Audio.sfx(good and "Ding" or "Buzzer")
			resultIcon.Text = good and "✓" or "×"
			resultIcon.TextColor3 = good and T.Good or T.Bad
			resultTitle.Text = (good and "COMPLETE: " or "FAILED: ") .. (r.title or "")
			resultDetail.Text = r.detail or ""
			resultFrame.Visible = true
			resultFrame.BackgroundColor3 = good and Color3.fromRGB(20, 50, 24) or Color3.fromRGB(60, 18, 16)
			task.wait(#resultQueue > 0 and 0.9 or 2.2)
		end
		resultFrame.Visible = false
		resultBusy = false
	end)
end
Hud.showResult = showResult

---------------------------------------------------------------- toasts
local toastList
local lastToast, lastToastAt = "", 0
local function toast(text, color)
	-- drop repeats and keep the stack short
	if text == lastToast and os.clock() - lastToastAt < 3 then
		return
	end
	lastToast, lastToastAt = text, os.clock()
	local existing = {}
	for _, c in ipairs(toastList:GetChildren()) do
		if c:IsA("TextLabel") then
			table.insert(existing, c)
		end
	end
	if #existing >= 5 then
		existing[1]:Destroy()
	end
	local t = Ui.label({
		Text = text,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.2,
		BackgroundColor3 = T.Panel,
		TextColor3 = color or T.Text,
		TextSize = 15,
		Parent = toastList,
	}, {})
	Ui.pad(6).Parent = t
	Ui.corner(6).Parent = t
	task.delay(5, function()
		TweenService:Create(t, TweenInfo.new(0.5), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		task.wait(0.5)
		t:Destroy()
	end)
end
Hud.toast = toast

---------------------------------------------------------------- captions
local capFrame, capSpeaker, capText, capBadge
local capToken = 0
local function showCaption(payload)
	capToken += 1
	local tok = capToken
	capSpeaker.Text = (payload.speaker == "Copy" and "???" or payload.speaker):upper()
	capText.Text = payload.text
	capBadge.Text = "📍 " .. (payload.source or "TV")
	capBadge.BackgroundColor3 = SOURCE_COLORS[payload.source] or T.Panel2
	capText.TextColor3 = payload.speaker == "Nell" and T.Nell or T.Text
	capText.Font = payload.style == "scream" and T.Bold or T.Font
	capText.TextSize = payload.style == "scream" and 44 or 24
	capFrame.Visible = true
	task.delay(math.max(2.5, (payload.duration or 2) + 1.2), function()
		if capToken == tok then
			capFrame.Visible = false
		end
	end)
end

---------------------------------------------------------------- build
function Hud.init(hudRoot)
	root = hudRoot

	-- top bar
	local top = Ui.new("Frame", {
		Size = UDim2.new(0, 520, 0, 54),
		Position = UDim2.new(0.5, -260, 0, 8),
		BackgroundColor3 = T.Bg,
		BackgroundTransparency = 0.25,
		Parent = root,
	}, { Ui.corner(10) })
	local chapterL = Ui.label({
		Text = "",
		Size = UDim2.new(0.62, -10, 0, 24),
		Position = UDim2.fromOffset(12, 4),
		Font = T.Bold,
		TextSize = 20,
		Parent = top,
	})
	local objectiveL = Ui.label({
		Text = "",
		Size = UDim2.new(1, -24, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(0, 12, 1, 6),
		TextSize = 15,
		TextColor3 = T.Text,
		BackgroundTransparency = 0.35,
		BackgroundColor3 = T.Bg,
		Parent = top,
	}, {})
	Ui.pad(4).Parent = objectiveL
	local modeL = Ui.label({
		Text = "",
		Size = UDim2.new(0.62, -10, 0, 18),
		Position = UDim2.fromOffset(12, 30),
		TextSize = 13,
		TextColor3 = T.Dim,
		Parent = top,
	})
	local timerL = Ui.label({
		Text = "",
		Size = UDim2.new(0.38, -12, 0, 30),
		Position = UDim2.new(0.62, 0, 0, 2),
		Font = T.Bold,
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = top,
	})
	local timerLabelL = Ui.label({
		Text = "",
		Size = UDim2.new(0.38, -12, 0, 16),
		Position = UDim2.new(0.62, 0, 0, 33),
		TextSize = 12,
		TextColor3 = T.Dim,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = top,
	})

	-- cue card
	local cue = Ui.new("Frame", {
		Size = UDim2.new(0, 620, 0, 110),
		Position = UDim2.new(0.5, -310, 0, 120),
		BackgroundColor3 = T.Bg,
		BackgroundTransparency = 0.15,
		Visible = false,
		Parent = root,
	}, { Ui.corner(10), Ui.stroke(T.Accent, 2) })
	local cueBadge = Ui.label({
		Text = "TV",
		Size = UDim2.new(0, 120, 0, 22),
		Position = UDim2.fromOffset(10, 8),
		BackgroundTransparency = 0,
		BackgroundColor3 = T.Accent,
		TextColor3 = Color3.new(0, 0, 0),
		Font = T.Bold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = cue,
	}, {})
	Ui.corner(6).Parent = cueBadge
	local cueText = Ui.label({
		Text = "",
		Size = UDim2.new(1, -20, 0, 36),
		Position = UDim2.fromOffset(10, 34),
		Font = T.Bold,
		TextSize = 26,
		TextColor3 = T.Nell,
		Parent = cue,
	})
	local cueHint = Ui.label({
		Text = "",
		Size = UDim2.new(1, -20, 0, 18),
		Position = UDim2.fromOffset(10, 72),
		TextSize = 14,
		TextColor3 = T.Dim,
		Parent = cue,
	})
	local cueBarBg = Ui.new("Frame", {
		Size = UDim2.new(1, -20, 0, 8),
		Position = UDim2.new(0, 10, 1, -14),
		BackgroundColor3 = T.Panel2,
		Parent = cue,
	}, { Ui.corner(4) })
	local cueBar = Ui.new(
		"Frame",
		{ Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.Accent, Parent = cueBarBg },
		{ Ui.corner(4) }
	)
	local cueTarget = Ui.label({
		Text = "",
		Size = UDim2.new(0, 200, 0, 22),
		Position = UDim2.new(1, -210, 0, 8),
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = T.Bold,
		TextSize = 15,
		Parent = cue,
	})
	local tickL = Ui.label({
		Text = "",
		Size = UDim2.new(0, 160, 0, 22),
		Position = UDim2.new(1, -170, 0, 72),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = T.Good,
		Font = T.Bold,
		TextSize = 15,
		Parent = cue,
	})
	local arrow = Ui.label({
		Text = "TURN AWAY FROM THE TV",
		Visible = false,
		Size = UDim2.new(0, 400, 0, 40),
		Position = UDim2.new(0.5, -200, 0.5, 60),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = T.Bold,
		TextSize = 26,
		TextColor3 = T.Accent,
		Parent = root,
	})
	local crouchRing = Ui.label({
		Text = "◯ HOLD CROUCH (C)",
		Visible = false,
		Size = UDim2.new(0, 400, 0, 34),
		Position = UDim2.new(0.5, -200, 0.5, 100),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = T.Bold,
		TextSize = 22,
		TextColor3 = Color3.new(1, 1, 1),
		Parent = root,
	})

	-- symbol picker
	local picker = Ui.new("Frame", {
		Size = UDim2.new(0, 520, 0, 90),
		Position = UDim2.new(0.5, -260, 0, 240),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = root,
	}, { Ui.list(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center) })
	local pickerOptions = ""
	local pickerCueId = -1
	local function buildPicker(opts)
		for _, c in ipairs(picker:GetChildren()) do
			if c:IsA("GuiButton") then
				c:Destroy()
			end
		end
		for i, sym in ipairs(opts) do
			local s = Config.Symbols[sym]
			local b = Ui.button({
				Text = (s and s.glyph or "?") .. "\n" .. sym:upper(),
				Size = UDim2.new(0, 110, 0, 84),
				TextColor3 = s and s.color or T.Text,
				TextSize = 22,
				Modal = true,
				LayoutOrder = i,
				Parent = picker,
			})
			b.Activated:Connect(function()
				Net.send("SymbolPick", sym)
				Audio.sfx("Click")
				picker.Visible = false
			end)
		end
	end

	-- caption box
	capFrame = Ui.new("Frame", {
		Size = UDim2.new(0, 760, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(0.5, -380, 1, -170),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		Visible = false,
		ZIndex = 70,
		Parent = root,
	}, { Ui.corner(8), Ui.pad(8) })
	capBadge = Ui.label({
		Text = "TV",
		Size = UDim2.new(0, 120, 0, 20),
		BackgroundTransparency = 0,
		BackgroundColor3 = T.Accent,
		TextColor3 = Color3.new(0, 0, 0),
		Font = T.Bold,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 71,
		Parent = capFrame,
	}, {})
	Ui.corner(5).Parent = capBadge
	capSpeaker = Ui.label({
		Text = "",
		Size = UDim2.new(1, -130, 0, 20),
		Position = UDim2.fromOffset(130, 0),
		Font = T.Bold,
		TextSize = 15,
		TextColor3 = T.Dim,
		ZIndex = 71,
		Parent = capFrame,
	})
	capText = Ui.label({
		Text = "",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromOffset(0, 24),
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 71,
		Parent = capFrame,
	})

	-- result flash
	resultFrame = Ui.new("Frame", {
		Size = UDim2.new(0, 460, 0, 74),
		Position = UDim2.new(0.5, -230, 0.36, 0),
		BackgroundColor3 = Color3.fromRGB(20, 50, 24),
		BackgroundTransparency = 0.1,
		Visible = false,
		ZIndex = 80,
		Parent = root,
	}, { Ui.corner(10) })
	resultIcon = Ui.label({
		Text = "✓",
		Size = UDim2.new(0, 64, 1, 0),
		TextSize = 52,
		Font = T.Bold,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 81,
		Parent = resultFrame,
	})
	resultTitle = Ui.label({
		Text = "",
		Size = UDim2.new(1, -80, 0, 30),
		Position = UDim2.fromOffset(70, 8),
		Font = T.Bold,
		TextSize = 20,
		ZIndex = 81,
		Parent = resultFrame,
	})
	resultDetail = Ui.label({
		Text = "",
		Size = UDim2.new(1, -80, 0, 30),
		Position = UDim2.fromOffset(70, 38),
		TextSize = 15,
		TextColor3 = T.Text,
		ZIndex = 81,
		Parent = resultFrame,
	})

	-- roster
	local roster = Ui.new("Frame", {
		Size = UDim2.new(0, 290, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromOffset(10, 80),
		BackgroundColor3 = T.Bg,
		BackgroundTransparency = 0.3,
		Parent = root,
	}, { Ui.corner(10), Ui.pad(8), Ui.list(nil, 4) })
	Ui.label({
		Text = "ROSTER",
		Font = T.Bold,
		TextSize = 13,
		TextColor3 = T.Dim,
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 16),
		Parent = roster,
	})
	local rows = {}
	for i = 1, 4 do
		rows[i] = Ui.label({
			Text = "",
			RichText = true,
			LayoutOrder = i,
			TextSize = 14,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = roster,
		})
	end
	local stationsL = Ui.label({
		Text = "",
		RichText = true,
		LayoutOrder = 10,
		TextSize = 13,
		TextColor3 = T.Dim,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = roster,
	})

	-- toasts
	toastList = Ui.new("Frame", {
		Size = UDim2.new(0, 320, 0, 300),
		Position = UDim2.new(1, -330, 1, -330),
		BackgroundTransparency = 1,
		Parent = root,
	}, {})
	local tl = Ui.list(nil, 4)
	tl.VerticalAlignment = Enum.VerticalAlignment.Bottom
	tl.Parent = toastList

	-- hide / warning banners
	local banner = Ui.label({
		Text = "",
		Visible = false,
		Size = UDim2.new(1, 0, 0, 56),
		Position = UDim2.new(0, 0, 0.5, -170),
		Font = T.Bold,
		TextSize = 40,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = T.Bad,
		Parent = root,
	})
	Ui.stroke(Color3.new(0, 0, 0), 2).Parent = banner
	local hiddenBar = Ui.new("Frame", {
		Size = UDim2.new(0, 360, 0, 50),
		Position = UDim2.new(0.5, -180, 1, -230),
		BackgroundColor3 = T.Bg,
		BackgroundTransparency = 0.2,
		Visible = false,
		Parent = root,
	}, { Ui.corner(10) })
	Ui.label({
		Text = "HIDDEN — watch through the gap",
		Size = UDim2.new(0.62, 0, 1, 0),
		Position = UDim2.fromOffset(10, 0),
		TextSize = 15,
		Parent = hiddenBar,
	})
	Ui.button({
		Text = "Leave (E)",
		Size = UDim2.new(0.34, 0, 0, 36),
		Position = UDim2.new(0.64, 0, 0, 7),
		Parent = hiddenBar,
	}, function()
		Net.send("HideExit")
	end)

	-- strikes overlay
	local stitch = Ui.label({
		Text = "",
		Visible = false,
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.new(0, 0, 0, 70),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = T.Bold,
		TextSize = 26,
		TextColor3 = T.Bad,
		Parent = root,
	})
	Ui.stroke(Color3.new(0, 0, 0), 2).Parent = stitch

	-- skip / vote / results / spectate
	local skipBtn = Ui.button({
		Text = "Vote to skip intro",
		Visible = false,
		Size = UDim2.new(0, 220, 0, 40),
		Position = UDim2.new(1, -236, 1, -60),
		ZIndex = 90,
		Modal = true,
		Parent = root,
	}, function()
		Net.send("SkipVote")
	end)
	local votePanel = Ui.new("Frame", {
		Size = UDim2.new(0, 520, 0, 150),
		Position = UDim2.new(0.5, -260, 0.5, -75),
		BackgroundColor3 = T.Bg,
		Visible = false,
		Parent = root,
	}, { Ui.corner(12), Ui.stroke(T.Accent, 2) })
	Ui.label({
		Text = "THE PARTY DECIDES",
		Font = T.Bold,
		TextSize = 22,
		Size = UDim2.new(1, -20, 0, 30),
		Position = UDim2.fromOffset(10, 8),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = votePanel,
	})
	local voteInfo = Ui.label({
		Text = "",
		TextSize = 14,
		TextColor3 = T.Dim,
		Size = UDim2.new(1, -20, 0, 20),
		Position = UDim2.fromOffset(10, 40),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = votePanel,
	})
	Ui.button({
		Text = "Stay for Sign-Off",
		Size = UDim2.new(0.45, 0, 0, 56),
		Position = UDim2.new(0.04, 0, 0, 74),
		Modal = true,
		Parent = votePanel,
	}, function()
		Net.send("Vote", "Stay")
		toast("You voted: Stay for Sign-Off")
	end)
	Ui.button({
		Text = "Pull the Disc",
		Size = UDim2.new(0.45, 0, 0, 56),
		Position = UDim2.new(0.51, 0, 0, 74),
		BackgroundColor3 = Color3.fromRGB(120, 30, 30),
		Parent = votePanel,
	}, function()
		Net.send("Vote", "Pull")
		toast("You voted: Pull the Disc")
	end)

	local results = Ui.new("Frame", {
		Size = UDim2.new(0, 640, 0, 420),
		Position = UDim2.new(0.5, -320, 0.5, -210),
		BackgroundColor3 = T.Bg,
		Visible = false,
		ZIndex = 100,
		Parent = root,
	}, { Ui.corner(14), Ui.stroke(T.Accent, 2) })
	local resTitle = Ui.label({
		Text = "",
		Font = T.Bold,
		TextSize = 34,
		Size = UDim2.new(1, -20, 0, 44),
		Position = UDim2.fromOffset(10, 14),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = T.Nell,
		ZIndex = 101,
		Parent = results,
	})
	local resList = Ui.new("Frame", {
		Size = UDim2.new(1, -40, 0, 260),
		Position = UDim2.fromOffset(20, 70),
		BackgroundTransparency = 1,
		ZIndex = 101,
		Parent = results,
	}, { Ui.list(nil, 8) })
	Ui.button({
		Text = "▶  REPLAY",
		Size = UDim2.new(0, 260, 0, 56),
		Position = UDim2.new(0.5, -130, 1, -76),
		BackgroundColor3 = T.Accent,
		TextColor3 = Color3.new(0, 0, 0),
		TextSize = 26,
		ZIndex = 102,
		Modal = true,
		Parent = results,
	}, function()
		Net.send("Replay")
	end)

	local specBar = Ui.new("Frame", {
		Size = UDim2.new(0, 460, 0, 50),
		Position = UDim2.new(0.5, -230, 1, -70),
		BackgroundColor3 = T.Bg,
		BackgroundTransparency = 0.2,
		Visible = false,
		Parent = root,
	}, { Ui.corner(10) })
	local specL = Ui.label({
		Text = "",
		Size = UDim2.new(0.5, 0, 1, 0),
		Position = UDim2.fromOffset(10, 0),
		TextSize = 14,
		Parent = specBar,
	})
	Ui.button({
		Text = "◀",
		Size = UDim2.new(0, 44, 0, 36),
		Position = UDim2.new(0.5, 0, 0, 7),
		Modal = true,
		Parent = specBar,
	}, function()
		Cinema.spectateNext(-1)
	end)
	Ui.button(
		{ Text = "▶", Size = UDim2.new(0, 44, 0, 36), Position = UDim2.new(0.5, 50, 0, 7), Parent = specBar },
		function()
			Cinema.spectateNext(1)
		end
	)
	Ui.button(
		{ Text = "TV stage", Size = UDim2.new(0, 110, 0, 36), Position = UDim2.new(0.5, 100, 0, 7), Parent = specBar },
		function()
			Cinema.spectateTv()
		end
	)

	-- ping bar + stamina
	local pingBar = Ui.new("Frame", {
		Size = UDim2.new(0, 560, 0, 30),
		Position = UDim2.new(0.5, -280, 1, -36),
		BackgroundTransparency = 1,
		Parent = root,
	}, { Ui.list(Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Center) })
	for i, label in ipairs({ "On my way", "I have this", "Help", "Hide", "Monster", "Ready" }) do
		Ui.button({
			Text = label,
			Size = UDim2.new(0, 88, 0, 26),
			TextSize = 13,
			LayoutOrder = i,
			BackgroundTransparency = 0.3,
			Parent = pingBar,
		}, function()
			Controls.ping(label)
		end)
	end
	local staminaBg = Ui.new("Frame", {
		Size = UDim2.new(0, 160, 0, 6),
		Position = UDim2.new(0.5, -80, 1, -46),
		BackgroundColor3 = T.Panel2,
		Parent = root,
	}, { Ui.corner(3) })
	local staminaFill = Ui.new(
		"Frame",
		{ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(200, 220, 255), Parent = staminaBg },
		{ Ui.corner(3) }
	)
	local crouchL = Ui.label({
		Text = "",
		Size = UDim2.new(0, 160, 0, 16),
		Position = UDim2.new(0.5, -80, 1, -66),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 13,
		TextColor3 = T.Dim,
		Parent = root,
	})
	local crosshair = Ui.label({
		Text = "·",
		Size = UDim2.fromOffset(20, 20),
		Position = UDim2.new(0.5, -10, 0.5, -10),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 28,
		Parent = root,
	})

	-- world markers for my stations (route pings)
	local stationBillboards = {}
	local function stationBillboard(name)
		if stationBillboards[name] then
			return stationBillboards[name]
		end
		local zones = workspace:FindFirstChild("House") and workspace.House:FindFirstChild("Zones")
		local z = zones and zones:FindFirstChild("Zone_" .. name)
		if not z then
			return nil
		end
		local bb = Ui.new("BillboardGui", {
			Size = UDim2.fromOffset(200, 50),
			StudsOffset = Vector3.new(0, 6, 0),
			AlwaysOnTop = true,
			Adornee = z,
			Enabled = false,
			Parent = game:GetService("Players").LocalPlayer.PlayerGui,
		})
		local l = Ui.label({
			Size = UDim2.fromScale(1, 1),
			TextScaled = true,
			Font = T.Bold,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = T.Accent,
			Parent = bb,
		})
		Ui.stroke(Color3.new(0, 0, 0), 2).Parent = l
		stationBillboards[name] = { bb = bb, label = l, zone = z }
		return stationBillboards[name]
	end

	---------------------------------------------------------------- events
	Net.on("Say", function(payload)
		showCaption(payload)
		if not payload.silent then
			Audio.voice(payload.speaker, payload.voiceText or payload.text, payload.style)
		end
	end)
	Net.on("Sfx", function(name, pos, vol)
		Audio.sfx(name, pos, vol)
	end)
	Net.on("Loop", function(name, on, vol)
		Audio.loop(name, on, vol)
	end)
	Net.on("Result", function(kind, title, detail)
		showResult(kind, title, detail)
	end)
	Net.on("Toast", function(text)
		toast(text)
	end)
	Net.on("CueTick", function(n, total)
		tickL.Text = ("✓ step %d/%d"):format(n, total)
		Audio.sfx("Click")
	end)
	Net.on("Strike", function(n, reason)
		stitch.Text = ("× STRIKE %d/3 — %s"):format(n, reason)
		stitch.Visible = true
		Audio.sfx("WoodClick")
		task.delay(3.5, function()
			stitch.Visible = false
		end)
	end)
	Net.on("Ping", function(slot, pos, label)
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.Transparency = 1
		part.Size = Vector3.new(0.2, 0.2, 0.2)
		part.Position = pos
		part.Parent = workspace
		local bb = Ui.new(
			"BillboardGui",
			{ Size = UDim2.fromOffset(150, 46), AlwaysOnTop = true, Adornee = part, Parent = part }
		)
		local l = Ui.label({
			Text = ("▼ P%d: %s"):format(slot, label),
			Size = UDim2.fromScale(1, 1),
			TextScaled = true,
			Font = T.Bold,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = slotColor(slot),
			Parent = bb,
		})
		Ui.stroke(Color3.new(0, 0, 0), 2).Parent = l
		Audio.sfx("Click", pos, 0.5)
		task.delay(6, function()
			part:Destroy()
		end)
	end)
	Net.on("Results", function(name, list)
		resTitle.Text = name:upper()
		for _, c in ipairs(resList:GetChildren()) do
			if c:IsA("TextLabel") then
				c:Destroy()
			end
		end
		table.sort(list, function(a, b)
			return a.slot < b.slot
		end)
		for _, r in ipairs(list) do
			Ui.label({
				Text = ('<b>P%d %s</b> — %s <font color="#aaa">(%s, %d strikes)</font>'):format(
					r.slot,
					r.name,
					r.outcome,
					r.cause ~= "" and r.cause or "—",
					r.strikes
				),
				RichText = true,
				TextSize = 18,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				ZIndex = 101,
				Parent = resList,
			})
		end
		local subtitle = ({
			["The Audience"] = "You stayed for the sign-off. The cast stays still.",
			["Off Air"] = "The disc is broken. Somebody made it to the street.",
			["Full Cast"] = '"Everyone made it."',
		})[name] or ""
		Ui.label({
			Text = subtitle,
			TextSize = 16,
			TextColor3 = T.Dim,
			LayoutOrder = -1,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 101,
			Parent = resList,
		})
	end)

	local lastCueId = -1
	RunService.RenderStepped:Connect(function()
		local phase = gs:GetAttribute("Phase") or "Lobby"
		local inGame = phase == "Playing" or phase == "Vote"
		top.Visible = phase ~= "Lobby"
		chapterL.Text = gs:GetAttribute("Chapter") or ""
		local mode = gs:GetAttribute("Mode") == "Quick" and "QUICK TEST" or "FULL EPISODE"
		modeL.Text = mode .. (gs:GetAttribute("Paused") and "   ⏸ CLOCK PAUSED" or "")
		local rem = gs:GetAttribute("TimerRemaining") or 0
		local tlabel = gs:GetAttribute("TimerLabel") or ""
		timerL.Text = tlabel ~= "" and fmtTime(rem) or ""
		timerLabelL.Text = tlabel
		timerL.TextColor3 = (tlabel ~= "" and rem < 6) and T.Bad or T.Text
		local obj = gs:GetAttribute("Objective") or ""
		objectiveL.Text = obj
		objectiveL.Visible = obj ~= "" and inGame

		-- cue card
		local cueTextS = gs:GetAttribute("CueText") or ""
		cue.Visible = cueTextS ~= "" and inGame
		if cue.Visible then
			local id = gs:GetAttribute("CueId") or 0
			if id ~= lastCueId then
				lastCueId = id
				tickL.Text = ""
			end
			cueText.Text = "“" .. cueTextS .. "”"
			local src = gs:GetAttribute("CueSource") or "TV"
			cueBadge.Text = "📍 " .. src
			cueBadge.BackgroundColor3 = SOURCE_COLORS[src] or T.Accent
			local kind = gs:GetAttribute("CueKind") or ""
			local window = gs:GetAttribute("CueWindow") or 1
			local crem = gs:GetAttribute("CueRemaining") or 0
			cueHint.Text = kind ~= ""
					and ("Response window %.0fs  •  %s"):format(window, gs:GetAttribute("CueHint") or "")
				or "listen..."
			cueBar.Size = UDim2.fromScale(kind ~= "" and math.clamp(crem / window, 0, 1) or 1, 1)
			cueBar.BackgroundColor3 = kind ~= "" and T.Accent or T.Panel2
			local target = gs:GetAttribute("CueTarget") or 0
			cueTarget.Text = target > 0 and ("→ PLAYER %d ONLY"):format(target) or ""
			cueTarget.TextColor3 = slotColor(target)
			arrow.Visible = kind == "lookaway"
			crouchRing.Visible = kind == "crouch"
			crouchRing.Text = Controls.isCrouching() and "● CROUCHED - HOLD IT" or "◯ HOLD CROUCH (C)"
			local opts = gs:GetAttribute("CueOptions") or ""
			if (kind == "symbol" or kind == "pick") and opts ~= "" and player:GetAttribute("Alive") then
				if pickerCueId ~= id then
					pickerCueId = id
					buildPicker(string.split(opts, ","))
					picker.Visible = true
				end
			else
				picker.Visible = false
			end
		else
			arrow.Visible = false
			crouchRing.Visible = false
			picker.Visible = false
		end

		-- roster
		local stFolder = gs:FindFirstChild("Stations")
		for i = 1, 4 do
			local p
			for _, pl in ipairs(Players:GetPlayers()) do
				if pl:GetAttribute("Slot") == i then
					p = pl
				end
			end
			local info = Config.Slots[i]
			local hex = info.color:ToHex()
			if p then
				local strikes = p:GetAttribute("Strikes") or 0
				local marks = string.rep("×", strikes) .. string.rep("·", math.max(0, 3 - strikes))
				local status = ""
				if not p:GetAttribute("Alive") then
					status = p:GetAttribute("Outcome") == "Escaped" and " ESCAPED" or " 🎭 PUPPET"
				elseif p:GetAttribute("Exited") then
					status = " ESCAPED"
				elseif p:GetAttribute("Hidden") then
					status = " (hidden)"
				end
				rows[i].Text = ('<font color="#%s"><b>P%d</b></font> %s <font color="#ff6a5a">%s</font>%s\n   <font size="12" color="#aaa">%s · %s</font>'):format(
					hex,
					i,
					p.DisplayName,
					marks,
					status,
					info.role,
					info.room
				)
			else
				rows[i].Text = ('<font color="#%s"><b>P%d</b></font> <font color="#888">(empty — covered by the team)</font>'):format(
					hex,
					i
				)
			end
		end
		local lines = {}
		if stFolder then
			for _, st in ipairs({ "Recorder", "Breaker", "TV", "Radio", "Console" }) do
				local f = stFolder:FindFirstChild(st)
				if f and (f:GetAttribute("Active") or f:GetAttribute("Done")) then
					local ownerSlot = f:GetAttribute("OwnerSlot") or 0
					local done = f:GetAttribute("Done")
					table.insert(
						lines,
						('%s %s → <font color="#%s">P%d</font> <font color="#888">(%s)</font>'):format(
							done and "✓" or "□",
							Config.StationInfo[st].label,
							slotColor(ownerSlot):ToHex(),
							ownerSlot,
							Config.ChallengeInfo[f:GetAttribute("Challenge") or "ReelTiming"].label
						)
					)
				end
				local bbInfo = stationBillboard(st)
				if bbInfo then
					local mine = f
						and f:GetAttribute("Active")
						and not f:GetAttribute("Done")
						and f:GetAttribute("Owner") == player.UserId
					bbInfo.bb.Enabled = mine == true
					bbInfo.label.Text = ("▼ YOUR STATION: %s"):format(Config.StationInfo[st].label)
					bbInfo.zone.Transparency = (f and f:GetAttribute("Active") and not f:GetAttribute("Done")) and 0.7
						or 1
				end
			end
		end
		stationsL.Text = #lines > 0 and ("STATIONS\n" .. table.concat(lines, "\n")) or ""
		roster.Visible = phase ~= "Lobby"

		-- hide / pursuit banners
		local hp = gs:GetAttribute("HidePhase") or "none"
		local chase = gs:GetAttribute("ChaseSlot") or 0
		if chase > 0 and chase == player:GetAttribute("Slot") then
			banner.Text = "IT SEES YOU — RUN!"
			banner.Visible = true
		elseif hp == "warning" then
			banner.Text = ("HIDE!  %ds"):format(math.ceil(rem))
			banner.Visible = true
		elseif hp == "patrol" or hp == "escape" then
			banner.Text = chase > 0 and ("THE PUPPETEER IS CHASING P%d"):format(chase) or ""
			banner.Visible = chase > 0
		else
			banner.Visible = false
		end
		hiddenBar.Visible = player:GetAttribute("Hidden") == true or (player:GetAttribute("HideSpot") or "") ~= ""

		-- intro skip
		skipBtn.Visible = Cinema.active and (gs:GetAttribute("ChapterIndex") or 0) == 1 and phase == "Playing"
		skipBtn.Text = ("Vote to skip (%d)"):format(gs:GetAttribute("SkipVotes") or 0)

		-- vote
		votePanel.Visible = phase == "Vote"
			and player:GetAttribute("Alive") == true
			and not player:GetAttribute("Exited")
		voteInfo.Text = ("%ds left · Stay %d · Pull %d · strict majority pulls the disc"):format(
			math.ceil(rem),
			gs:GetAttribute("VoteStay") or 0,
			gs:GetAttribute("VotePull") or 0
		)

		results.Visible = phase == "Results"

		-- spectate
		local spec = Cinema.isSpectating()
		specBar.Visible = spec and not Cinema.active
		if spec then
			local t = Cinema.spectateTarget()
			specL.Text = t and ("Spectating P%d %s"):format(t:GetAttribute("Slot") or 0, t.DisplayName)
				or "Watching the TV stage"
		end
		pingBar.Visible = inGame and player:GetAttribute("Alive") == true
		staminaBg.Visible = inGame and player:GetAttribute("Alive") == true
		staminaFill.Size = UDim2.fromScale(Controls.stamina(), 1)
		crouchL.Text = Controls.isCrouching() and "CROUCHING (C)" or ""
		crosshair.Visible = not Cinema.active and player:GetAttribute("Alive") == true
	end)
end

return Hud

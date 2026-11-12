-- Station challenge UIs. The server generates the puzzle and validates every answer.
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config)
local Ui = require(script.Parent.Ui)
local Audio = require(script.Parent.Audio)
local T = Ui.Theme

local Mg = {}
local root
local cur -- current session UI state

local function glyph(sym)
	local s = Config.Symbols[sym]
	return s and s.glyph or "?"
end
local function symColor(sym)
	local s = Config.Symbols[sym]
	return s and s.color or T.Text
end

local function close()
	if cur then
		if cur.conns then
			for _, c in ipairs(cur.conns) do
				c:Disconnect()
			end
		end
		if cur.frame then
			cur.frame:Destroy()
		end
		cur = nil
	end
	game:GetService("ContextActionService"):UnbindAction("HushMgBlock")
	ProximityPromptService.Enabled = true
end

function Mg.isOpen()
	return cur ~= nil
end

local function send(action, a, b)
	if cur then
		Net.send("Mg", cur.id, action, a, b)
	end
end

local function setStatus(text, color)
	if cur and cur.status then
		cur.status.Text = text
		cur.status.TextColor3 = color or T.Text
	end
end

local function setPips(n)
	if not cur then
		return
	end
	for i, p in ipairs(cur.pips) do
		p.BackgroundColor3 = i <= n and T.Good or T.Panel2
		p.Text = i <= n and "✓" or ""
	end
end

local function symbolButton(parent, sym, size, onClick)
	local b = Ui.button({
		Size = size or UDim2.new(0, 96, 0, 96),
		BackgroundColor3 = T.Panel2,
		Text = glyph(sym) .. "\n" .. sym:upper(),
		TextColor3 = symColor(sym),
		TextSize = 22,
		Parent = parent,
	}, onClick)
	b.TextWrapped = true
	return b
end

---------------------------------------------------------------- builders per kind
local build = {}

build.Timing = function(body, data)
	local bar = Ui.new("Frame", {
		Size = UDim2.new(1, -20, 0, 54),
		Position = UDim2.new(0, 10, 0, 10),
		BackgroundColor3 = Color3.fromRGB(30, 30, 30),
		Parent = body,
	}, { Ui.corner(6) })
	local band = Ui.new(
		"Frame",
		{ Size = UDim2.new(data.band, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(60, 190, 80), Parent = bar },
		{ Ui.corner(4) }
	)
	-- hatched brackets so colour is optional
	Ui.label({
		Text = "[▒▒▒▒▒▒▒]",
		Size = UDim2.fromScale(1, 1),
		TextScaled = true,
		TextColor3 = Color3.fromRGB(20, 60, 20),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Ui.Theme.Mono,
		Parent = band,
	})
	local marker = Ui.new("Frame", {
		Size = UDim2.new(0, 6, 1, 16),
		Position = UDim2.new(0, 0, 0, -8),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 3,
		Parent = bar,
	})
	local press = Ui.button({
		Text = "PRESS  (E / X)",
		Size = UDim2.new(0, 260, 0, 64),
		Position = UDim2.new(0.5, -130, 0, 82),
		BackgroundColor3 = T.Accent,
		TextColor3 = Color3.new(0, 0, 0),
		TextSize = 24,
		Parent = body,
	})
	local bandPos = math.random() * (1 - data.band)
	band.Position = UDim2.fromScale(bandPos, 0)
	local t0 = os.clock()
	local function markerX()
		local phase = ((os.clock() - t0) / data.period) % 2
		return phase <= 1 and phase or (2 - phase)
	end
	local function hit()
		local x = markerX()
		if x >= bandPos and x <= bandPos + data.band then
			Audio.sfx("Click")
			send("hit")
			setStatus("HIT!", T.Good)
			local nb
			repeat
				nb = math.random() * (1 - data.band)
			until math.abs(nb - bandPos) > 0.2
			bandPos = nb
			band.Position = UDim2.fromScale(bandPos, 0)
		else
			setStatus(x < bandPos and "Too early - try again" or "Too late - try again", T.Bad)
		end
	end
	press.Activated:Connect(hit)
	table.insert(
		cur.conns,
		RunService.RenderStepped:Connect(function()
			marker.Position = UDim2.new(markerX(), -3, 0, -8)
		end)
	)
	cur.onKey = function(key)
		if key == Enum.KeyCode.E or key == Enum.KeyCode.ButtonX or key == Enum.KeyCode.Space then
			hit()
		end
	end
end

build.Sequence = function(body, data)
	local row = Ui.new(
		"Frame",
		{ Size = UDim2.new(1, 0, 0, 100), Position = UDim2.new(0, 0, 0, 30), BackgroundTransparency = 1, Parent = body },
		{ Ui.list(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center) }
	)
	local entered = {}
	local buttons = {}
	local flashing = false
	local seqLabel = Ui.label({
		Text = "",
		Size = UDim2.new(1, 0, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = body,
	})
	local function showEntered()
		local s = {}
		for _, e in ipairs(entered) do
			table.insert(s, glyph(e))
		end
		seqLabel.Text = "Your order: " .. table.concat(s, "  ")
	end
	local function flash()
		flashing = true
		entered = {}
		showEntered()
		setStatus("Watch the order...", T.Accent)
		task.wait(0.6)
		for _, sym in ipairs(data.flash) do
			local b = buttons[sym]
			if not cur or not b.Parent then
				return
			end
			b.BackgroundColor3 = symColor(sym)
			b.TextColor3 = Color3.new(0, 0, 0)
			Audio.sfx("Click")
			task.wait(0.55)
			b.BackgroundColor3 = T.Panel2
			b.TextColor3 = symColor(sym)
			task.wait(0.2)
		end
		flashing = false
		setStatus("Now repeat it (click or keys 1-4)", T.Text)
	end
	local function press(sym)
		if flashing or #entered >= 4 then
			return
		end
		table.insert(entered, sym)
		Audio.sfx("Click")
		showEntered()
		if #entered == 4 then
			send("answer", entered)
		end
	end
	for i, sym in ipairs(data.buttons) do
		buttons[sym] = symbolButton(row, sym, nil, function()
			press(sym)
		end)
		buttons[sym].LayoutOrder = i
		buttons[sym].Text = ("%s\n%d %s"):format(glyph(sym), i, sym:upper())
	end
	cur.onWrong = function()
		task.spawn(flash)
	end
	cur.onKey = function(key)
		local map =
			{ [Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3, [Enum.KeyCode.Four] = 4 }
		if map[key] then
			press(data.buttons[map[key]])
		end
	end
	task.spawn(flash)
end

build.Tuning = function(body, data)
	local idx = 1
	local dial = 0.5
	local held = 0
	local dir = 0
	local targetLabel = Ui.label({
		Text = "",
		Size = UDim2.new(1, 0, 0, 30),
		TextSize = 22,
		Font = T.Bold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = body,
	})
	local scale = Ui.new("Frame", {
		Size = UDim2.new(1, -20, 0, 60),
		Position = UDim2.new(0, 10, 0, 36),
		BackgroundColor3 = Color3.fromRGB(20, 22, 26),
		Parent = body,
	}, { Ui.corner(6) })
	-- symbols printed along the dial (targets + decoys)
	local decoys = { "Club", "Heart", "Cross", "Diamond", "Circle", "Square" }
	local marks = {}
	for _, t in ipairs(data.targets) do
		table.insert(marks, { sym = t.symbol, pos = t.pos })
	end
	for i = 1, 4 do
		local s = decoys[i]
		local used = false
		for _, m in ipairs(marks) do
			if m.sym == s then
				used = true
			end
		end
		if not used then
			table.insert(marks, { sym = s, pos = 0.05 + (i - 1) * 0.3 + 0.13 })
		end
	end
	for _, m in ipairs(marks) do
		Ui.label({
			Text = glyph(m.sym),
			TextColor3 = symColor(m.sym),
			Size = UDim2.new(0, 30, 0, 30),
			Position = UDim2.new(m.pos, -15, 0, 2),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextSize = 24,
			Parent = scale,
		})
	end
	local needle = Ui.new("Frame", {
		Size = UDim2.new(0, 4, 1, 10),
		Position = UDim2.new(0.5, -2, 0, -5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 3,
		Parent = scale,
	})
	local holdBar = Ui.new(
		"Frame",
		{ Size = UDim2.new(0, 0, 0, 8), Position = UDim2.new(0, 10, 0, 104), BackgroundColor3 = T.Good, Parent = body }
	)
	local row = Ui.new(
		"Frame",
		{ Size = UDim2.new(1, 0, 0, 50), Position = UDim2.new(0, 0, 0, 120), BackgroundTransparency = 1, Parent = body },
		{ Ui.list(Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Center) }
	)
	local left = Ui.button({ Text = "◀  A", Size = UDim2.new(0, 120, 0, 48), Parent = row })
	local right = Ui.button({ Text = "D  ▶", Size = UDim2.new(0, 120, 0, 48), Parent = row })
	left.MouseButton1Down:Connect(function()
		dir = -1
	end)
	right.MouseButton1Down:Connect(function()
		dir = 1
	end)
	left.MouseButton1Up:Connect(function()
		dir = 0
	end)
	right.MouseButton1Up:Connect(function()
		dir = 0
	end)
	local function refreshTarget()
		local t = data.targets[idx]
		targetLabel.Text = t and ("Find signal %d/2:  %s %s"):format(idx, glyph(t.symbol), t.symbol:upper())
			or "Both signals locked"
	end
	refreshTarget()
	local keyDir = 0
	table.insert(
		cur.conns,
		RunService.RenderStepped:Connect(function(dt)
			local d = dir ~= 0 and dir or keyDir
			dial = math.clamp(dial + d * dt * 0.32, 0, 1)
			local t = data.targets[idx]
			local jitter = 0
			if t then
				local dist = math.abs(dial - t.pos)
				jitter = math.min(dist, 0.2) * 0.08 * math.sin(os.clock() * 40)
				if dist <= data.tolerance then
					held += dt
					setStatus("Signal found - hold it...", T.Good)
					if held >= data.hold then
						send("lock", idx)
						Audio.sfx("Click")
						idx += 1
						held = 0
						refreshTarget()
					end
				else
					held = 0
					setStatus(dist < 0.12 and "Close... the hiss is softening" or "Hiss. Turn the dial.", T.Dim)
				end
			end
			needle.Position = UDim2.new(math.clamp(dial + jitter, 0, 1), -2, 0, -5)
			holdBar.Size = UDim2.new(0, 480 * math.clamp(held / data.hold, 0, 1), 0, 8)
		end)
	)
	cur.onKey = function(key, down)
		if key == Enum.KeyCode.A or key == Enum.KeyCode.Left or key == Enum.KeyCode.DPadLeft then
			keyDir = down and -1 or (keyDir == -1 and 0 or keyDir)
		elseif key == Enum.KeyCode.D or key == Enum.KeyCode.Right or key == Enum.KeyCode.DPadRight then
			keyDir = down and 1 or (keyDir == 1 and 0 or keyDir)
		end
	end
	cur.wantsKeyUp = true
end

build.Match = function(body, data)
	local idx = 1
	local screen = Ui.new("Frame", {
		Size = UDim2.new(0, 140, 0, 100),
		Position = UDim2.new(0.5, -70, 0, 0),
		BackgroundColor3 = Color3.fromRGB(20, 40, 30),
		Parent = body,
	}, { Ui.corner(10), Ui.stroke(Color3.fromRGB(170, 170, 170), 3) })
	local shown = Ui.label({
		Size = UDim2.fromScale(1, 1),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = screen,
	})
	local row = Ui.new("Frame", {
		Size = UDim2.new(1, 0, 0, 100),
		Position = UDim2.new(0, 0, 0, 110),
		BackgroundTransparency = 1,
		Parent = body,
	}, { Ui.list(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center) })
	local function render()
		for _, c in ipairs(row:GetChildren()) do
			if c:IsA("GuiButton") then
				c:Destroy()
			end
		end
		local s = data.screens[idx]
		if not s then
			shown.Text = "✓"
			return
		end
		shown.Text = glyph(s.symbol)
		shown.TextColor3 = symColor(s.symbol)
		for i, sym in ipairs(s.buttons) do
			local b = symbolButton(row, sym, nil, function()
				send("answer", idx, sym)
				cur.pendingSym = sym
			end)
			b.LayoutOrder = i
			b.Text = ("%s\n%d %s"):format(glyph(sym), i, sym:upper())
		end
		setStatus(("Screen %d/3: press the matching button"):format(idx), T.Text)
	end
	cur.onTick = function(n)
		idx = n + 1
		render()
	end
	cur.onKey = function(key)
		local map =
			{ [Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3, [Enum.KeyCode.Four] = 4 }
		local s = data.screens[idx]
		if map[key] and s then
			send("answer", idx, s.buttons[map[key]])
		end
	end
	render()
end

build.Patch = function(body, data)
	local selected
	local locked = {}
	local leftCol = Ui.new("Frame", {
		Size = UDim2.new(0.4, 0, 0, 200),
		Position = UDim2.new(0.05, 0, 0, 0),
		BackgroundTransparency = 1,
		Parent = body,
	}, { Ui.list(nil, 6) })
	local rightCol = Ui.new("Frame", {
		Size = UDim2.new(0.4, 0, 0, 200),
		Position = UDim2.new(0.55, 0, 0, 0),
		BackgroundTransparency = 1,
		Parent = body,
	}, { Ui.list(nil, 6) })
	local btns = { L = {}, R = {} }
	local function paint()
		for side, list in pairs(btns) do
			for sym, b in pairs(list) do
				if locked[sym] then
					b.BackgroundColor3 = T.Good
					b.TextColor3 = Color3.new(0, 0, 0)
				elseif selected and selected.side == side and selected.sym == sym then
					b.BackgroundColor3 = T.Accent
					b.TextColor3 = Color3.new(0, 0, 0)
				else
					b.BackgroundColor3 = T.Panel2
					b.TextColor3 = symColor(sym)
				end
			end
		end
	end
	local function tap(side, sym)
		if locked[sym] then
			return
		end
		Audio.sfx("Click")
		if selected and selected.side ~= side then
			local l = side == "L" and sym or selected.sym
			local r = side == "R" and sym or selected.sym
			send("pair", l, r)
			selected = nil
		else
			selected = { side = side, sym = sym }
		end
		paint()
	end
	for i, sym in ipairs(data.left) do
		local b = Ui.button({
			Text = glyph(sym) .. "  " .. sym:upper() .. "  ——",
			Size = UDim2.new(1, 0, 0, 44),
			LayoutOrder = i,
			Parent = leftCol,
		}, function()
			tap("L", sym)
		end)
		btns.L[sym] = b
	end
	for i, sym in ipairs(data.right) do
		local b = Ui.button({
			Text = "——  " .. glyph(sym) .. "  " .. sym:upper(),
			Size = UDim2.new(1, 0, 0, 44),
			LayoutOrder = i,
			Parent = rightCol,
		}, function()
			tap("R", sym)
		end)
		btns.R[sym] = b
	end
	cur.onTick = function(_, msg)
		if msg then
			locked[msg] = true
		end
		paint()
	end
	cur.onWrong = function()
		paint()
	end
	paint()
	setStatus("Tap a cable end, then the matching shape on the other side", T.Text)
end

build.Channel = function(body, data)
	local ch = 1
	local confirmed = {}
	local tgt = Ui.label({
		Text = "",
		Size = UDim2.new(1, 0, 0, 28),
		TextSize = 20,
		Font = T.Bold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = body,
	})
	local codes = {}
	for i, t in ipairs(data.targets) do
		local g = {}
		for _, s in ipairs(t) do
			table.insert(g, glyph(s))
		end
		codes[i] = table.concat(g, " ")
	end
	tgt.Text = "Find:  [" .. codes[1] .. "]   and   [" .. codes[2] .. "]"
	local dialBox = Ui.new("Frame", {
		Size = UDim2.new(0, 300, 0, 90),
		Position = UDim2.new(0.5, -150, 0, 34),
		BackgroundColor3 = Color3.fromRGB(30, 20, 14),
		Parent = body,
	}, { Ui.corner(8) })
	local chLabel = Ui.label({
		Size = UDim2.new(1, 0, 0.45, 0),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = T.Mono,
		TextColor3 = Color3.fromRGB(255, 190, 100),
		Parent = dialBox,
	})
	local codeLabel = Ui.label({
		Size = UDim2.new(1, 0, 0.55, 0),
		Position = UDim2.fromScale(0, 0.45),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = dialBox,
	})
	local row = Ui.new(
		"Frame",
		{ Size = UDim2.new(1, 0, 0, 50), Position = UDim2.new(0, 0, 0, 132), BackgroundTransparency = 1, Parent = body },
		{ Ui.list(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center) }
	)
	local function render()
		chLabel.Text = ("CH %02d%s"):format(ch, confirmed[ch] and "  ✓" or "")
		local g = {}
		for _, s in ipairs(data.channels[ch]) do
			table.insert(g, glyph(s))
		end
		codeLabel.Text = table.concat(g, "  ")
		Audio.sfx("Click", nil, 0.5)
	end
	local function turn(d)
		ch = (ch - 1 + d) % #data.channels + 1
		render()
	end
	Ui.button({ Text = "◀ A", Size = UDim2.new(0, 100, 0, 46), LayoutOrder = 1, Parent = row }, function()
		turn(-1)
	end)
	Ui.button({
		Text = "CONFIRM (E)",
		Size = UDim2.new(0, 160, 0, 46),
		LayoutOrder = 2,
		BackgroundColor3 = T.Accent,
		TextColor3 = Color3.new(0, 0, 0),
		Parent = row,
	}, function()
		send("confirm", ch)
	end)
	Ui.button({ Text = "D ▶", Size = UDim2.new(0, 100, 0, 46), LayoutOrder = 3, Parent = row }, function()
		turn(1)
	end)
	cur.onTick = function(_, msg)
		if msg then
			confirmed[msg] = true
		end
		render()
	end
	cur.onKey = function(key)
		if key == Enum.KeyCode.A or key == Enum.KeyCode.Left or key == Enum.KeyCode.DPadLeft then
			turn(-1)
		elseif key == Enum.KeyCode.D or key == Enum.KeyCode.Right or key == Enum.KeyCode.DPadRight then
			turn(1)
		elseif key == Enum.KeyCode.E or key == Enum.KeyCode.ButtonX then
			send("confirm", ch)
		end
	end
	render()
	setStatus("Turn the dial. Confirm the two channels whose code matches.", T.Text)
end

---------------------------------------------------------------- shell
local function open(data)
	close()
	ProximityPromptService.Enabled = false
	-- keep the operator in place while using A/D on the dial
	game:GetService("ContextActionService"):BindActionAtPriority(
		"HushMgBlock",
		function()
			return Enum.ContextActionResult.Sink
		end,
		false,
		3000,
		Enum.KeyCode.W,
		Enum.KeyCode.A,
		Enum.KeyCode.S,
		Enum.KeyCode.D,
		Enum.KeyCode.Up,
		Enum.KeyCode.Down,
		Enum.KeyCode.Left,
		Enum.KeyCode.Right,
		Enum.KeyCode.Space
	)
	local frame = Ui.new("TextButton", {
		Name = "Minigame",
		Text = "",
		AutoButtonColor = false,
		Modal = true, -- frees the mouse in first person
		Size = UDim2.new(0, 560, 0, 380),
		Position = UDim2.new(0.5, -280, 1, -430),
		BackgroundColor3 = T.Bg,
		BackgroundTransparency = 0.05,
		ZIndex = 1,
		Parent = root,
	}, { Ui.corner(12), Ui.stroke(T.Accent, 2) })
	Ui.label({
		Text = ("%s  —  %s"):format(data.label, data.challengeLabel),
		Font = T.Bold,
		TextSize = 20,
		Size = UDim2.new(1, -60, 0, 26),
		Position = UDim2.fromOffset(14, 10),
		Parent = frame,
	})
	Ui.label({
		Text = data.help,
		TextSize = 14,
		TextColor3 = T.Dim,
		Size = UDim2.new(1, -28, 0, 34),
		Position = UDim2.fromOffset(14, 36),
		Parent = frame,
	})
	Ui.button(
		{ Text = "X", Size = UDim2.new(0, 36, 0, 36), Position = UDim2.new(1, -46, 0, 8), Parent = frame },
		function()
			Net.send("Mg", data.id, "close")
			close()
		end
	)
	local pipRow = Ui.new("Frame", {
		Size = UDim2.new(1, -28, 0, 26),
		Position = UDim2.fromOffset(14, 72),
		BackgroundTransparency = 1,
		Parent = frame,
	}, { Ui.list(Enum.FillDirection.Horizontal, 6) })
	local need = ({ Timing = 3, Sequence = 1, Tuning = 2, Match = 3, Patch = 4, Channel = 2 })[data.kind] or 1
	local pips = {}
	for i = 1, need do
		pips[i] = Ui.new("TextLabel", {
			Size = UDim2.new(0, 26, 0, 26),
			BackgroundColor3 = T.Panel2,
			Text = "",
			Font = T.Bold,
			TextSize = 18,
			TextColor3 = Color3.new(0, 0, 0),
			Parent = pipRow,
		}, { Ui.corner(13) })
	end
	local body = Ui.new("Frame", {
		Size = UDim2.new(1, -28, 0, 200),
		Position = UDim2.fromOffset(14, 104),
		BackgroundTransparency = 1,
		Parent = frame,
	})
	local status = Ui.label({
		Text = "",
		Size = UDim2.new(1, -28, 0, 24),
		Position = UDim2.new(0, 14, 1, -62),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = T.Bold,
		Parent = frame,
	})
	local lockBar = Ui.new("Frame", {
		Size = UDim2.new(1, -28, 0, 10),
		Position = UDim2.new(0, 14, 1, -28),
		BackgroundColor3 = T.Panel2,
		Parent = frame,
	}, { Ui.corner(5) })
	local lockFill = Ui.new(
		"Frame",
		{ Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.Accent, Parent = lockBar },
		{ Ui.corner(5) }
	)
	Ui.label({
		Text = ("Work window: stay in the zone at least %ds"):format(data.minDuration),
		TextSize = 12,
		TextColor3 = T.Dim,
		Size = UDim2.new(1, -28, 0, 14),
		Position = UDim2.new(0, 14, 1, -44),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = frame,
	})
	cur = {
		id = data.id,
		frame = frame,
		pips = pips,
		status = status,
		conns = {},
		data = data,
		start = os.clock(),
		min = data.minDuration,
	}
	table.insert(
		cur.conns,
		RunService.RenderStepped:Connect(function()
			if cur then
				lockFill.Size = UDim2.fromScale(math.clamp((os.clock() - cur.start) / cur.min, 0, 1), 1)
			end
		end)
	)
	build[data.kind](body, data.data)
end

function Mg.init(hudRoot)
	root = hudRoot
	Net.on("MgOpen", open)
	Net.on("MgTick", function(id, n, need, msg)
		if cur and cur.id == id then
			setPips(n)
			if cur.onTick then
				cur.onTick(n, msg)
			end
			if n >= need then
				setStatus("Complete - hold position while it locks", T.Good)
			end
		end
	end)
	Net.on("MgWrong", function(id, msg)
		if cur and cur.id == id then
			setStatus(msg, T.Bad)
			Audio.sfx("Click", nil, 0.6)
			if cur.onWrong then
				cur.onWrong()
			end
		end
	end)
	Net.on("MgLocking", function(rem)
		if cur then
			setStatus(rem > 0 and ("Locking... %.1fs (stay in the zone)"):format(rem) or "Locked", T.Good)
		end
	end)
	Net.on("MgClose", function(id, why)
		if cur and cur.id == id then
			close()
		end
	end)
	UserInputService.InputBegan:Connect(function(input, gpe)
		if cur and cur.onKey and input.KeyCode ~= Enum.KeyCode.Unknown then
			cur.onKey(input.KeyCode, true)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if cur and cur.onKey and cur.wantsKeyUp then
			cur.onKey(input.KeyCode, false)
		end
	end)
end

Mg.close = close
return Mg

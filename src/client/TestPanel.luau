-- Studio-only test panel (toggle with the TEST button or F2). Server also rejects admin calls outside Studio.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config)
local Ui = require(script.Parent.Ui)
local T = Ui.Theme

local TestPanel = {}

function TestPanel.init(root)
	if not RunService:IsStudio() then
		return
	end
	local gs = ReplicatedStorage:WaitForChild("GameState")
	local toggle = Ui.button({
		Text = "TEST",
		Size = UDim2.new(0, 64, 0, 28),
		Position = UDim2.new(1, -74, 0, 8),
		TextSize = 14,
		BackgroundColor3 = Color3.fromRGB(90, 40, 120),
		ZIndex = 200,
		Parent = root,
	})
	local panel = Ui.new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Modal = true,
		Size = UDim2.new(0, 300, 0, 520),
		Position = UDim2.new(1, -310, 0, 42),
		BackgroundColor3 = Color3.fromRGB(24, 18, 32),
		BackgroundTransparency = 0.05,
		Visible = false,
		ZIndex = 200,
		Parent = root,
	}, { Ui.corner(10), Ui.stroke(Color3.fromRGB(150, 90, 200), 2) })
	local function vis(on)
		panel.Visible = on
	end
	toggle.Activated:Connect(function()
		vis(not panel.Visible)
	end)
	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.F2 then
			vis(not panel.Visible)
		end
	end)
	local y = 8
	local function row(h)
		local r = Ui.new("Frame", {
			Size = UDim2.new(1, -16, 0, h),
			Position = UDim2.fromOffset(8, y),
			BackgroundTransparency = 1,
			ZIndex = 201,
			Parent = panel,
		})
		y += h + 6
		return r
	end
	Ui.label({ Text = "STUDIO TEST PANEL", Font = T.Bold, TextSize = 15, ZIndex = 201, Parent = row(20) })
	local info = Ui.label({
		Text = "",
		RichText = true,
		TextSize = 13,
		ZIndex = 201,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.fromScale(1, 1),
		Parent = row(150),
	})

	Ui.label({ Text = "Jump to chapter", TextSize = 12, TextColor3 = T.Dim, ZIndex = 201, Parent = row(14) })
	local ch = row(64)
	for i, name in ipairs(Config.Chapters) do
		Ui.button({
			Text = ("%d %s"):format(i, name),
			TextSize = 11,
			Size = UDim2.new(0, 68, 0, 28),
			Position = UDim2.fromOffset(((i - 1) % 4) * 71, (i - 1) // 4 * 32),
			ZIndex = 202,
			Parent = ch,
		}, function()
			Net.send("Admin", "jump", i)
		end)
	end

	Ui.label({ Text = "Selected player", TextSize = 12, TextColor3 = T.Dim, ZIndex = 201, Parent = row(14) })
	local selRow = row(32)
	local selected = 1
	local selBtn = Ui.button(
		{ Text = "", Size = UDim2.new(1, 0, 1, 0), TextSize = 14, ZIndex = 202, Parent = selRow },
		function()
			selected += 1
		end
	)
	local function selectedPlayer()
		local list = Players:GetPlayers()
		table.sort(list, function(a, b)
			return (a:GetAttribute("Slot") or 9) < (b:GetAttribute("Slot") or 9)
		end)
		if #list == 0 then
			return nil
		end
		return list[(selected - 1) % #list + 1]
	end
	local actions = row(32)
	Ui.button(
		{ Text = "+1 Strike", Size = UDim2.new(0.48, 0, 1, 0), TextSize = 14, ZIndex = 202, Parent = actions },
		function()
			local p = selectedPlayer()
			if p then
				Net.send("Admin", "strike", p.UserId)
			end
		end
	)
	Ui.button({
		Text = "Eliminate",
		Size = UDim2.new(0.48, 0, 1, 0),
		Position = UDim2.fromScale(0.52, 0),
		TextSize = 14,
		ZIndex = 202,
		BackgroundColor3 = Color3.fromRGB(110, 30, 30),
		Parent = actions,
	}, function()
		local p = selectedPlayer()
		if p then
			Net.send("Admin", "kill", p.UserId)
		end
	end)
	Ui.button(
		{ Text = "Start HIDE patrol", Size = UDim2.new(1, 0, 1, 0), TextSize = 14, ZIndex = 202, Parent = row(32) },
		function()
			Net.send("Admin", "hide")
		end
	)
	local r2 = row(32)
	Ui.button(
		{ Text = "Force start", Size = UDim2.new(0.48, 0, 1, 0), TextSize = 14, ZIndex = 202, Parent = r2 },
		function()
			Net.send("Admin", "start")
		end
	)
	Ui.button({
		Text = "Restart session",
		Size = UDim2.new(0.48, 0, 1, 0),
		Position = UDim2.fromScale(0.52, 0),
		TextSize = 14,
		ZIndex = 202,
		BackgroundColor3 = Color3.fromRGB(120, 80, 20),
		Parent = r2,
	}, function()
		Net.send("Admin", "restart")
	end)

	RunService.RenderStepped:Connect(function()
		if not panel.Visible then
			return
		end
		local p = selectedPlayer()
		selBtn.Text = p and ("▶ P%d %s (click to cycle)"):format(p:GetAttribute("Slot") or 0, p.DisplayName)
			or "no players"
		local living, lines = 0, {}
		for _, pl in ipairs(Players:GetPlayers()) do
			local alive = pl:GetAttribute("Alive") and not pl:GetAttribute("Exited")
			if alive then
				living += 1
			end
			table.insert(
				lines,
				("P%d %s: %d strikes, %s%s"):format(
					pl:GetAttribute("Slot") or 0,
					pl.DisplayName,
					pl:GetAttribute("Strikes") or 0,
					alive and "alive" or (pl:GetAttribute("Outcome") or "out"),
					pl:GetAttribute("Hidden") and ", hidden" or ""
				)
			)
		end
		local st = {}
		for _, f in ipairs(gs.Stations:GetChildren()) do
			if f:GetAttribute("Active") or f:GetAttribute("Done") then
				table.insert(
					st,
					("%s→P%d%s"):format(
						f.Name,
						f:GetAttribute("OwnerSlot") or 0,
						f:GetAttribute("Done") and "✓" or ""
					)
				)
			end
		end
		local rem = gs:GetAttribute("TimerRemaining") or 0
		info.Text = ("<b>Phase:</b> %s  <b>Mode:</b> %s\n<b>Chapter:</b> %s\n<b>Timer:</b> %s %.1fs%s\n<b>Living:</b> %d  <b>Puppets:</b> %d\n%s\n<b>Stations:</b> %s"):format(
			gs:GetAttribute("Phase") or "?",
			gs:GetAttribute("Mode") or "?",
			gs:GetAttribute("Chapter") or "-",
			gs:GetAttribute("TimerLabel") or "",
			rem,
			gs:GetAttribute("Paused") and " (paused)" or "",
			living,
			gs:GetAttribute("PuppetCount") or 0,
			table.concat(lines, "\n"),
			#st > 0 and table.concat(st, ", ") or "none"
		)
	end)
end

return TestPanel
